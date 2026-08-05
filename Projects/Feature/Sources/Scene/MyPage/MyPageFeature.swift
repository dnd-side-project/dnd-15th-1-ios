import Domain
import Foundation
import ThirdParty

@Reducer
public struct MyPageFeature {
    @ObservableState
    public struct State: Equatable {
        public var user: AuthUser?
        public var isLoading = false
        public var errorMessage: String?

        public init(
            user: AuthUser? = nil,
            isLoading: Bool = false,
            errorMessage: String? = nil
        ) {
            self.user = user
            self.isLoading = isLoading
            self.errorMessage = errorMessage
        }
    }

    public enum Action: Equatable {
        case onAppear
        case logoutButtonTapped
        case signOutResponse(Result<EquatableVoid, AuthError>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case signOutSucceeded
            case sessionExpired
        }
    }

    public struct EquatableVoid: Equatable, Sendable {
        public init() {}
    }

    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case .logoutButtonTapped:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { [authClient] send in
                    do {
                        try await authClient.signOut()
                        await send(.signOutResponse(.success(EquatableVoid())))
                    } catch {
                        await send(.signOutResponse(.failure(mapAuthError(error))))
                    }
                }

            case .signOutResponse(.success):
                state.isLoading = false
                state.user = nil
                return .send(.delegate(.signOutSucceeded))

            case let .signOutResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = "로그아웃에 실패했습니다."
                if error == .sessionExpired {
                    return .send(.delegate(.sessionExpired))
                }
                return .none

            case .delegate:
                return .none
            }
        }
    }
}

private func mapAuthError(_ error: Error) -> AuthError {
    error as? AuthError ?? .unknown
}
