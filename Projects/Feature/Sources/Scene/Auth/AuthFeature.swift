import Domain
import Foundation
import ThirdParty

@Reducer
public struct AuthFeature {
    @ObservableState
    public struct State: Equatable {
        public var isLoading = false
        public var errorMessage: String?

        public init(
            isLoading: Bool = false,
            errorMessage: String? = nil
        ) {
            self.isLoading = isLoading
            self.errorMessage = errorMessage
        }
    }

    public enum Action: Equatable {
        case onAppear
        case loginButtonTapped
        case signInResponse(Result<AuthUser, AuthError>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case signInSucceeded(AuthUser)
        }
    }

    @Dependency(\.authClient) var authClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none

            case .loginButtonTapped:
                guard !state.isLoading else { return .none }
                state.isLoading = true
                state.errorMessage = nil
                return .run { [authClient] send in
                    do {
                        let user = try await authClient.signIn()
                        await send(.signInResponse(.success(user)))
                    } catch {
                        await send(.signInResponse(.failure(mapAuthError(error))))
                    }
                }

            case let .signInResponse(.success(user)):
                state.isLoading = false
                return .send(.delegate(.signInSucceeded(user)))

            case .signInResponse(.failure):
                state.isLoading = false
                state.errorMessage = "로그인에 실패했습니다."
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
