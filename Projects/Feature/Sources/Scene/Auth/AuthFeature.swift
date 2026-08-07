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
        case loginResponse(Result<AuthSession, AuthError>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case loginSucceeded(userID: String)
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
                        // Temporary default provider until multi-provider UI lands.
                        let session = try await authClient.login(.kakao)
                        await send(.loginResponse(.success(session)))
                    } catch {
                        await send(.loginResponse(.failure(mapAuthError(error))))
                    }
                }

            case let .loginResponse(.success(session)):
                state.isLoading = false
                return .send(.delegate(.loginSucceeded(userID: session.userID)))

            case .loginResponse(.failure):
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
