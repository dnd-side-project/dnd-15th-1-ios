import Domain
import Foundation
import ThirdParty

@Reducer
public struct AppCoordinatorFeature {
    @ObservableState
    public struct State: Equatable {
        public var phase: Phase = .bootstrapping
        public var currentUserID: String?
        public var pendingDeepLink: DeepLinkRoute?
        public var overlay = OverlayFeature.State()

        public init(
            phase: Phase = .bootstrapping,
            currentUserID: String? = nil,
            pendingDeepLink: DeepLinkRoute? = nil,
            overlay: OverlayFeature.State = OverlayFeature.State()
        ) {
            self.phase = phase
            self.currentUserID = currentUserID
            self.pendingDeepLink = pendingDeepLink
            self.overlay = overlay
        }

        public enum Phase: Equatable {
            case bootstrapping
            case appIntro(AppIntroFeature.State)
            case loggedOut(AuthFeature.State)
            case main(MainTabFeature.State)
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

        public var loggedOutAuth: AuthFeature.State? {
            get {
                guard case let .loggedOut(auth) = phase else { return nil }
                return auth
            }
            set {
                if let newValue {
                    phase = .loggedOut(newValue)
                }
            }
        }

        public var mainTab: MainTabFeature.State? {
            get {
                guard case let .main(tab) = phase else { return nil }
                return tab
            }
            set {
                if let newValue {
                    phase = .main(newValue)
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
        case appIntro(AppIntroFeature.Action)
        case auth(AuthFeature.Action)
        case mainTab(MainTabFeature.Action)
        case overlay(OverlayFeature.Action)
        case sessionExpired

        public enum BootstrapRoute: Equatable {
            case appIntro
            case loggedOut
        }
    }

    @Dependency(\.authClient) var authClient
    @Dependency(\.onboardingClient) var onboardingClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.overlay, action: \.overlay) {
            OverlayFeature()
        }
        Reduce(core)
            .ifLet(\.appIntro, action: \.appIntro) {
                AppIntroFeature()
            }
            .ifLet(\.loggedOutAuth, action: \.auth) {
                AuthFeature()
            }
            .ifLet(\.mainTab, action: \.mainTab) {
                MainTabFeature()
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
            state.phase = .loggedOut(AuthFeature.State())
            return .none
        case let .deepLinkReceived(url):
            return receiveDeepLink(url)
        case let .routeDeepLink(route):
            return routeDeepLink(state: &state, route: route)
        case .flushPendingDeepLink:
            return flushPendingDeepLink(state: &state)
        case let .appIntro(.delegate(delegate)):
            return handleAppIntroDelegate(delegate: delegate)
        case let .auth(.delegate(delegate)):
            return handleAuthDelegate(state: &state, delegate: delegate)
        case let .mainTab(.delegate(delegate)):
            return handleMainTabDelegate(state: &state, delegate: delegate)
        case .sessionExpired:
            return moveToLoggedOut(state: &state)
        case .appIntro, .auth, .mainTab, .overlay:
            return .none
        }
    }
}

private extension AppCoordinatorFeature {
    func restoreSessionIfNeeded(state: inout State) -> Effect<Action> {
        guard case .bootstrapping = state.phase else {
            return .none
        }
        return .run { [authClient] send in
            do {
                let bootstrap = try await authClient.restoreSession()
                await send(.sessionRestored(.success(bootstrap)))
            } catch {
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
            state.currentUserID = bootstrap?.session.userID
            if let bootstrap {
                // Temporary: ignore flag until onboarding phase Cycle.
                state.phase = .main(makeMainState(userID: bootstrap.session.userID))
                return .send(.flushPendingDeepLink)
            }
            return resolveLoggedOutBootstrapRoute()
        case .failure:
            state.currentUserID = nil
            return resolveLoggedOutBootstrapRoute()
        }
    }

    func resolveLoggedOutBootstrapRoute() -> Effect<Action> {
        .run { [onboardingClient] send in
            let seen = await onboardingClient.hasSeenAppIntro()
            await send(.bootstrapRoute(seen ? .loggedOut : .appIntro))
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
        case .loggedOut:
            state.phase = .loggedOut(AuthFeature.State())
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
        case .appIntro:
            switch route {
            case .signIn:
                return .none
            case .home, .explore, .map, .myPage:
                state.pendingDeepLink = route
                return .none
            }
        case .loggedOut:
            switch route {
            case .signIn:
                return .none
            case .home, .explore, .map, .myPage:
                state.pendingDeepLink = route
                return .none
            }
        case .main:
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

    func handleAuthDelegate(
        state: inout State,
        delegate: AuthFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case let .loginSucceeded(userID):
            state.currentUserID = userID
            state.phase = .main(makeMainState(userID: userID))
            return .send(.flushPendingDeepLink)
        }
    }

    func handleMainTabDelegate(
        state: inout State,
        delegate: MainTabFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .logoutSucceeded:
            return moveToLoggedOut(state: &state)
        case .sessionExpired:
            return .send(.sessionExpired)
        }
    }

    func moveToLoggedOut(state: inout State) -> Effect<Action> {
        state.currentUserID = nil
        state.phase = .loggedOut(AuthFeature.State())
        return .none
    }

    func makeMainState(userID: String) -> MainTabFeature.State {
        MainTabFeature.State(
            selectedTab: .home,
            home: HomeFeature.State(),
            explore: ExploreFeature.State(),
            map: MapFeature.State(),
            myPage: MyPageFeature.State(userID: userID)
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

        state.phase = .main(main)
        return .none
    }
}

private extension AppCoordinatorFeature.State.Phase {
    var mainTabState: MainTabFeature.State? {
        guard case let .main(state) = self else { return nil }
        return state
    }
}

private func mapAuthError(_ error: Error) -> AuthError {
    error as? AuthError ?? .unknown
}
