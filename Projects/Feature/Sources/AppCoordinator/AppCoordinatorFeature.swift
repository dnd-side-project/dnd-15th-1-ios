import Domain
import Foundation
import ThirdParty

@Reducer
public struct AppCoordinatorFeature {
    @ObservableState
    public struct State: Equatable {
        public var phase: Phase = .bootstrapping
        public var currentSession: AuthSession?
        public var pendingDeepLink: DeepLinkRoute?
        public var overlay = OverlayFeature.State()

        public init(
            phase: Phase = .bootstrapping,
            currentSession: AuthSession? = nil,
            pendingDeepLink: DeepLinkRoute? = nil,
            overlay: OverlayFeature.State = OverlayFeature.State()
        ) {
            self.phase = phase
            self.currentSession = currentSession
            self.pendingDeepLink = pendingDeepLink
            self.overlay = overlay
        }

        public enum Phase: Equatable {
            case bootstrapping
            case loggedOut(AuthFeature.State)
            case main(MainTabFeature.State)
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
        case sessionRestored(Result<AuthSession?, AuthError>)
        case deepLinkReceived(URL)
        case routeDeepLink(DeepLinkRoute)
        case flushPendingDeepLink
        case auth(AuthFeature.Action)
        case mainTab(MainTabFeature.Action)
        case overlay(OverlayFeature.Action)
        case unauthorized
    }

    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.overlay, action: \.overlay) {
            OverlayFeature()
        }
        Reduce(core)
            .ifLet(\.loggedOutAuth, action: \.auth) {
                AuthFeature()
            }
            .ifLet(\.mainTab, action: \.mainTab) {
                MainTabFeature()
            }
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .onAppear:
            return restoreSessionIfNeeded(state: &state)
        case let .sessionRestored(result):
            return applySessionRestored(state: &state, result: result)
        case let .deepLinkReceived(url):
            return receiveDeepLink(url)
        case let .routeDeepLink(route):
            return routeDeepLink(state: &state, route: route)
        case .flushPendingDeepLink:
            return flushPendingDeepLink(state: &state)
        case let .auth(.delegate(delegate)):
            return handleAuthDelegate(state: &state, delegate: delegate)
        case let .mainTab(.delegate(delegate)):
            return handleMainTabDelegate(state: &state, delegate: delegate)
        case .unauthorized:
            return moveToLoggedOut(state: &state)
        case .auth, .mainTab, .overlay:
            return .none
        }
    }

    private func restoreSessionIfNeeded(state: inout State) -> Effect<Action> {
        guard case .bootstrapping = state.phase else {
            return .none
        }
        return .run { [authClient] send in
            do {
                let session = try await authClient.restoreSession()
                await send(.sessionRestored(.success(session)))
            } catch {
                await send(.sessionRestored(.failure(mapAuthError(error))))
            }
        }
    }

    private func applySessionRestored(
        state: inout State,
        result: Result<AuthSession?, AuthError>
    ) -> Effect<Action> {
        switch result {
        case let .success(session):
            state.currentSession = session
            if let session {
                state.phase = .main(makeMainState(session: session))
                return .send(.flushPendingDeepLink)
            }
            state.phase = .loggedOut(AuthFeature.State())
            return .none
        case .failure:
            return moveToLoggedOut(state: &state)
        }
    }

    private func receiveDeepLink(_ url: URL) -> Effect<Action> {
        guard let route = DeepLinkRouter.parse(url) else {
            return .none
        }
        return .send(.routeDeepLink(route))
    }

    private func routeDeepLink(
        state: inout State,
        route: DeepLinkRoute
    ) -> Effect<Action> {
        switch state.phase {
        case .bootstrapping:
            state.pendingDeepLink = route
            return .none
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

    private func flushPendingDeepLink(state: inout State) -> Effect<Action> {
        guard let route = state.pendingDeepLink else {
            return .none
        }
        state.pendingDeepLink = nil
        return .send(.routeDeepLink(route))
    }

    private func handleAuthDelegate(
        state: inout State,
        delegate: AuthFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case let .loginSucceeded(session):
            state.currentSession = session
            state.phase = .main(makeMainState(session: session))
            return .send(.flushPendingDeepLink)
        }
    }

    private func handleMainTabDelegate(
        state: inout State,
        delegate: MainTabFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .logoutSucceeded:
            return moveToLoggedOut(state: &state)
        case .unauthorized:
            return .send(.unauthorized)
        }
    }

    private func moveToLoggedOut(state: inout State) -> Effect<Action> {
        state.currentSession = nil
        state.phase = .loggedOut(AuthFeature.State())
        return .none
    }

    private func makeMainState(session: AuthSession) -> MainTabFeature.State {
        MainTabFeature.State(
            selectedTab: .home,
            home: HomeFeature.State(),
            explore: ExploreFeature.State(),
            map: MapFeature.State(),
            myPage: MyPageFeature.State(session: session)
        )
    }

    private func routeInMain(
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
