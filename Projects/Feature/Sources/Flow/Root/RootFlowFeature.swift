import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct RootFlowFeature {
    @ObservableState
    public struct State: Equatable {
        public var phase: Phase = .bootstrapping
        public var pendingDeepLink: DeepLinkRoute?
        public var overlay = OverlayFeature.State()
        @Presents public var placeImport: PlaceImportFeature.State?

        public init(
            phase: Phase = .bootstrapping,
            pendingDeepLink: DeepLinkRoute? = nil,
            overlay: OverlayFeature.State = OverlayFeature.State(),
            placeImport: PlaceImportFeature.State? = nil
        ) {
            self.phase = phase
            self.pendingDeepLink = pendingDeepLink
            self.overlay = overlay
            self.placeImport = placeImport
        }

        /// `onboardingFlow` 는 로그인 root 위에 온보딩이 쌓이는 한 스택이다. 둘은 같은 phase 를 쓴다.
        /// 이 phase 는 mainTab 에 닿기 전 화면 구간(로그인 포함)을 가리키고, `isOnboardingCompleted` 는 닉네임 제출 여부를 알리는 서버 플래그다
        public enum Phase: Equatable {
            case bootstrapping
            case appIntro(AppIntroFeature.State)
            case onboardingFlow(OnboardingFlowFeature.State)
            case mainTab(MainTabFeature.State)
        }

        public var appIntro: AppIntroFeature.State? {
            get {
                guard case let .appIntro(state) = phase else { return nil }
                return state
            }
            set {
                if let newValue {
                    phase = .appIntro(newValue)
                }
            }
        }

        public var onboardingFlow: OnboardingFlowFeature.State? {
            get {
                guard case let .onboardingFlow(state) = phase else { return nil }
                return state
            }
            set {
                if let newValue {
                    phase = .onboardingFlow(newValue)
                }
            }
        }

        public var mainTab: MainTabFeature.State? {
            get {
                guard case let .mainTab(tab) = phase else { return nil }
                return tab
            }
            set {
                if let newValue {
                    phase = .mainTab(newValue)
                }
            }
        }
    }

    public enum Action: Equatable {
        case onAppear
        case sessionRestored(Result<AuthBootstrap?, AuthError>)
        case bootstrapRoute(BootstrapRoute)
        case appIntroFinished
        case deepLinkReceived(URL)
        case routeDeepLink(DeepLinkRoute)
        case flushPendingDeepLink
        case onboardingSessionResolved(userID: String?)
        case appIntro(AppIntroFeature.Action)
        case onboardingFlow(OnboardingFlowFeature.Action)
        case mainTab(MainTabFeature.Action)
        case overlay(OverlayFeature.Action)
        case placeImport(PresentationAction<PlaceImportFeature.Action>)
        case sessionExpired

        public enum BootstrapRoute: Equatable {
            case appIntro
            case signIn
        }
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.onboardingClient) var onboardingClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.continuousClock) var clock

    public init() {}

    private enum CancelID {
        case pushRegistration
    }

    /// FCM 토큰이 올 때마다 기기를 등록한다. 구독 시 마지막 토큰을 먼저 받으므로
    /// 로그인 직후와 앱 재실행 직후에도 한 번 등록된다.
    private var registerPushDevice: Effect<Action> {
        .run { [notificationClient] _ in
            for await token in await notificationClient.fcmTokenStream() {
                do {
                    try await notificationClient.registerDevice(token)
                } catch {
                    FeatureLog.error(
                        scene: "RootFlow",
                        operation: "registerPushDevice",
                        error: String(describing: error),
                        userVisible: false
                    )
                }
            }
        }
        .cancellable(id: CancelID.pushRegistration, cancelInFlight: true)
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.overlay, action: \.overlay) {
            OverlayFeature()
        }
        Reduce(core)
            .ifLet(\.appIntro, action: \.appIntro) {
                AppIntroFeature()
            }
            .ifLet(\.onboardingFlow, action: \.onboardingFlow) {
                OnboardingFlowFeature()
            }
            .ifLet(\.mainTab, action: \.mainTab) {
                MainTabFeature()
            }
            .ifLet(\.$placeImport, action: \.placeImport) {
                PlaceImportFeature()
            }
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return restoreSessionIfNeeded(state: &state)
        case let .sessionRestored(result):
            return applySessionRestored(state: &state, result: result)
        case let .bootstrapRoute(route):
            return applyBootstrapRoute(state: &state, route: route)
        case .appIntroFinished:
            state.phase = .onboardingFlow(OnboardingFlowFeature.State())
            return .none
        case let .deepLinkReceived(url):
            return receiveDeepLink(url)
        case let .routeDeepLink(route):
            return routeDeepLink(state: &state, route: route)
        case .flushPendingDeepLink:
            return flushPendingDeepLink(state: &state)
        case let .onboardingSessionResolved(userID):
            return applyOnboardingSession(state: &state, userID: userID)
        case .sessionExpired:
            return moveToSignIn(state: &state)
        case .placeImport:
            return .none
        case .appIntro, .onboardingFlow, .mainTab, .overlay:
            return childDelegate(state: &state, action: action)
        }
    }

    private func childDelegate(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .appIntro(.delegate(delegate)):
            return handleAppIntroDelegate(delegate: delegate)
        case let .onboardingFlow(.delegate(delegate)):
            return handleOnboardingFlowDelegate(state: &state, delegate: delegate)
        case let .mainTab(.delegate(delegate)):
            return handleMainTabDelegate(state: &state, delegate: delegate)
        default:
            return .none
        }
    }
}

private extension RootFlowFeature {
    func restoreSessionIfNeeded(state: inout State) -> Effect<Action> {
        guard case .bootstrapping = state.phase else {
            return .none
        }
        return .run { [authClient, clock] send in
            // 스플래시가 한 프레임 스치고 사라지지 않게 최소 노출을 함께 기다린다
            async let minimumDisplay: Void? = try? await clock.sleep(for: .seconds(1))
            do {
                let bootstrap = try await authClient.restoreSession()
                _ = await minimumDisplay
                await send(.sessionRestored(.success(bootstrap)))
            } catch {
                _ = await minimumDisplay
                await send(.sessionRestored(.failure(mapAuthError(error))))
            }
        }
    }

    func applySessionRestored(
        state: inout State,
        result: Result<AuthBootstrap?, AuthError>
    ) -> Effect<Action> {
        switch result {
        case let .success(bootstrap):
            if let bootstrap {
                return moveAfterAuthentication(
                    state: &state,
                    userID: bootstrap.session.userID,
                    isOnboardingCompleted: bootstrap.isOnboardingCompleted
                )
            }
            return resolveSignedOutBootstrapRoute()
        case .failure:
            return resolveSignedOutBootstrapRoute()
        }
    }

    func resolveSignedOutBootstrapRoute() -> Effect<Action> {
        .run { [onboardingClient] send in
            let seen = await onboardingClient.hasSeenAppIntro()
            await send(.bootstrapRoute(seen ? .signIn : .appIntro))
        }
    }

    func applyBootstrapRoute(
        state: inout State,
        route: Action.BootstrapRoute
    ) -> Effect<Action> {
        switch route {
        case .appIntro:
            state.phase = .appIntro(AppIntroFeature.State())
            return .run { [onboardingClient] _ in
                await onboardingClient.markAppIntroSeen()
            }
        case .signIn:
            state.phase = .onboardingFlow(OnboardingFlowFeature.State())
            return .none
        }
    }

    func handleAppIntroDelegate(
        delegate: AppIntroFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .completed:
            return .send(.appIntroFinished)
        }
    }

    func receiveDeepLink(_ url: URL) -> Effect<Action> {
        guard let route = DeepLinkRouter.parse(url) else {
            return .none
        }
        return .send(.routeDeepLink(route))
    }

    func routeDeepLink(
        state: inout State,
        route: DeepLinkRoute
    ) -> Effect<Action> {
        switch state.phase {
        case .bootstrapping:
            state.pendingDeepLink = route
            return .none
        case .appIntro, .onboardingFlow:
            switch route {
            case .signIn:
                return .none
            case .home, .explore, .map, .myPage, .placeImport:
                state.pendingDeepLink = route
                return .none
            }
        case .mainTab:
            return routeInMain(state: &state, route: route)
        }
    }

    func flushPendingDeepLink(state: inout State) -> Effect<Action> {
        guard let route = state.pendingDeepLink else {
            return .none
        }
        state.pendingDeepLink = nil
        return .send(.routeDeepLink(route))
    }

    func handleOnboardingFlowDelegate(
        state: inout State,
        delegate: OnboardingFlowFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case let .authenticated(userID, isOnboardingCompleted):
            let requestNotificationAuthorization = Effect<Action>.run { [notificationClient] _ in
                _ = await notificationClient.requestAuthorization()
            }
            guard isOnboardingCompleted else {
                // 스택은 이미 닉네임을 올렸다. 여기서는 phase 를 건드리지 않는다
                return .merge(requestNotificationAuthorization, registerPushDevice)
            }
            return .merge(
                requestNotificationAuthorization,
                registerPushDevice,
                moveToMain(state: &state, userID: userID)
            )
        case .onboardingCompleted:
            return resolveOnboardingSession()
        case .signedOut:
            // 스택은 이미 로그인 root 로 물러났다. 구독만 끊는다
            return .cancel(id: CancelID.pushRegistration)
        case .sessionExpired:
            return .send(.sessionExpired)
        }
    }

    /// 온보딩 끝에서만 세션을 묻는다. RootFlow 는 userID 사본을 들고 있지 않다
    func resolveOnboardingSession() -> Effect<Action> {
        .run { [authClient] send in
            let session = try? await authClient.currentSession()
            await send(.onboardingSessionResolved(userID: session?.userID))
        }
    }

    /// 온보딩은 인증 뒤에만 들어오므로, 세션이 비었다면 사라진 것이다
    func applyOnboardingSession(state: inout State, userID: String?) -> Effect<Action> {
        guard let userID else {
            return moveToSignIn(state: &state)
        }
        return moveToMain(state: &state, userID: userID)
    }

    /// 세션 복구 결과로 phase 를 정한다. 온보딩 미완료면 닉네임이 올라간 스택으로 들어간다
    func moveAfterAuthentication(
        state: inout State,
        userID: String,
        isOnboardingCompleted: Bool
    ) -> Effect<Action> {
        guard isOnboardingCompleted else {
            state.phase = .onboardingFlow(.resumingOnboarding)
            return registerPushDevice
        }
        return .merge(registerPushDevice, moveToMain(state: &state, userID: userID))
    }

    func moveToMain(state: inout State, userID: String) -> Effect<Action> {
        state.phase = .mainTab(makeMainState(userID: userID))
        return .send(.flushPendingDeepLink)
    }

    func handleMainTabDelegate(
        state: inout State,
        delegate: MainTabFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .logoutSucceeded:
            // 로그인 화면에 로그아웃 완료를 텍스트 토스트로 알린다
            return moveToSignIn(state: &state, toast: ToastState(message: "로그아웃 되었습니다."))
        case .accountWithdrawn:
            return moveToSignIn(state: &state, toast: ToastState(message: "탈퇴가 완료되었습니다."))
        case .sessionExpired:
            return .send(.sessionExpired)
        }
    }

    func moveToSignIn(state: inout State, toast: ToastState? = nil) -> Effect<Action> {
        // 이 경로로 로그인 화면에 돌아오면 푸시 등록 구독을 끊는다
        state.phase = .onboardingFlow(
            OnboardingFlowFeature.State(auth: AuthFeature.State(toast: toast))
        )
        return .cancel(id: CancelID.pushRegistration)
    }

    func makeMainState(userID: String) -> MainTabFeature.State {
        MainTabFeature.State(
            selectedTab: .home,
            home: HomeFeature.State(),
            explore: ExploreFeature.State(),
            map: MapFlowFeature.State(map: MapFeature.State()),
            myPage: MyPageFeature.State()
        )
    }

    func routeInMain(
        state: inout State,
        route: DeepLinkRoute
    ) -> Effect<Action> {
        guard var main = state.phase.mainTabState else {
            state.pendingDeepLink = route
            return .none
        }

        switch route {
        case let .placeImport(url):
            state.placeImport = PlaceImportFeature.State(link: url)
            return .none
        case .signIn:
            return .none
        case .home:
            main.selectedTab = .home
        case .explore:
            main.selectedTab = .explore
        case .map:
            main.selectedTab = .map
        case .myPage:
            main.selectedTab = .myPage
        }

        state.phase = .mainTab(main)
        return .none
    }
}

private extension RootFlowFeature.State.Phase {
    var mainTabState: MainTabFeature.State? {
        guard case let .mainTab(state) = self else { return nil }
        return state
    }
}

private func mapAuthError(_ error: Error) -> AuthError {
    error as? AuthError ?? .unknown
}
