import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

/// main 에 닿기 전까지의 화면 스택. 로그인이 root 이고 온보딩 화면이 그 위로 쌓인다
@Reducer
public struct OnboardingFlowFeature {
    /// 로그인(root) 위로 쌓이는 화면. 커플 세 화면은 `CoupleConnectFeature.State` 하나를 공유한다
    public enum Route: Hashable {
        case nickname
        case couple
        case coupleCodeInput
        case coupleComplete
    }

    @ObservableState
    public struct State: Equatable {
        public var auth: AuthFeature.State
        public var nickname: NicknameFeature.State
        public var couple: CoupleConnectFeature.State?
        public var dateType: DateTypeFeature.State?
        public var path: [Route]

        public init(
            auth: AuthFeature.State = AuthFeature.State(),
            nickname: NicknameFeature.State = NicknameFeature.State(),
            couple: CoupleConnectFeature.State? = nil,
            dateType: DateTypeFeature.State? = nil,
            path: [Route] = []
        ) {
            self.auth = auth
            self.nickname = nickname
            self.couple = couple
            self.dateType = dateType
            self.path = path
        }

        /// 세션은 살아 있는데 온보딩이 남은 경우. 로그인을 root 로 깔아 둔 채 닉네임부터 보여준다
        public static var resumingOnboarding: State {
            State(path: [.nickname])
        }
    }

    public enum Action: Equatable {
        case pathChanged([Route])
        case signOutFinished(AuthError?)
        case auth(AuthFeature.Action)
        case nickname(NicknameFeature.Action)
        case couple(CoupleConnectFeature.Action)
        case dateType(DateTypeFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case authenticated(userID: String, isOnboardingCompleted: Bool)
            case onboardingCompleted
            case signedOut
            case sessionExpired
        }
    }

    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.auth, action: \.auth) {
            AuthFeature()
        }
        Scope(state: \.nickname, action: \.nickname) {
            NicknameFeature()
        }
        Reduce(core)
            .ifLet(\.couple, action: \.couple) {
                CoupleConnectFeature()
            }
            .ifLet(\.dateType, action: \.dateType) {
                DateTypeFeature()
            }
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .pathChanged(path):
            return pathChanged(path, state: &state)
        case let .signOutFinished(error):
            return signOutFinished(error, state: &state)
        case let .auth(.delegate(delegate)):
            return handleAuthDelegate(state: &state, delegate: delegate)
        case let .nickname(.delegate(delegate)):
            return handleNicknameDelegate(state: &state, delegate: delegate)
        case let .couple(.delegate(delegate)):
            return handleCoupleDelegate(state: &state, delegate: delegate)
        case let .dateType(.delegate(delegate)):
            return handleDateTypeDelegate(state: &state, delegate: delegate)
        case .auth, .nickname, .couple, .dateType, .delegate:
            return .none
        }
    }
}

private extension OnboardingFlowFeature {
    /// 뷰가 경로를 줄여 로그인 root 까지 내려왔다면 온보딩을 그만둔 것이다
    func pathChanged(_ path: [Route], state: inout State) -> Effect<Action> {
        let returnedToSignIn = !state.path.isEmpty && path.isEmpty
        state.path = path
        guard returnedToSignIn else { return .none }
        return signOut(state: &state)
    }

    func handleAuthDelegate(
        state: inout State,
        delegate: AuthFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case let .loginSucceeded(userID, isOnboardingCompleted):
            if !isOnboardingCompleted {
                state.nickname = NicknameFeature.State()
                state.path = [.nickname]
            }
            return .send(
                .delegate(
                    .authenticated(userID: userID, isOnboardingCompleted: isOnboardingCompleted)
                )
            )
        }
    }

    func handleNicknameDelegate(
        state: inout State,
        delegate: NicknameFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case let .nicknameConfirmed(profile):
            state.couple = CoupleConnectFeature.State(myNickname: profile.nickname)
            state.path.append(.couple)
            return .none
        case .back:
            state.path = []
            return signOut(state: &state)
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }

    func handleCoupleDelegate(
        state: inout State,
        delegate: CoupleConnectFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .showCodeInput:
            state.path.append(.coupleCodeInput)
            return .none
        case .showComplete:
            state.path.append(.coupleComplete)
            return .none
        case .back:
            // 뺄 경로가 없으면 물러설 곳도 없다
            guard !state.path.isEmpty else { return .none }
            state.path.removeLast()
            return .none
        case .connected, .skipped:
            state.dateType = DateTypeFeature.State()
            return .none
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }

    func handleDateTypeDelegate(
        state: inout State,
        delegate: DateTypeFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .saved, .skipped:
            // 덮개는 여기서 비우지 않는다. main 으로 갈아탄 뒤 그 위에서 내려가야 커플 화면이 드러나지 않는다
            return .send(.delegate(.onboardingCompleted))
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }

    /// 닉네임 화면은 물러나는 중이라 여기서 비우지 않는다. 다음 로그인 때 새 값으로 덮는다
    func signOut(state: inout State) -> Effect<Action> {
        state.couple = nil
        state.dateType = nil
        return .run { [authClient] send in
            do {
                try await authClient.logout()
                await send(.signOutFinished(nil))
            } catch {
                await send(.signOutFinished(mapAuthError(error)))
            }
        }
    }

    /// 화면은 이미 로그인으로 돌아왔다. 실패해도 되돌리지 않고 알리기만 한다
    func signOutFinished(_ error: AuthError?, state: inout State) -> Effect<Action> {
        if error != nil {
            state.auth.toast = .error("로그아웃에 실패했습니다.")
        }
        return .send(.delegate(.signedOut))
    }
}

private func mapAuthError(_ error: Error) -> AuthError {
    error as? AuthError ?? .unknown
}
