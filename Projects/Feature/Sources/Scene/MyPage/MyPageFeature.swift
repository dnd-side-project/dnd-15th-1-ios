import Domain
import Foundation
import ThirdParty

@Reducer
public struct MyPageFeature {
    @ObservableState
    public struct State: Equatable {
        public var userID: String?
        public var isLoading = false
        public var errorMessage: String?

        public init(
            userID: String? = nil,
            isLoading: Bool = false,
            errorMessage: String? = nil
        ) {
            self.userID = userID
            self.isLoading = isLoading
            self.errorMessage = errorMessage
        }
    }

    public enum Action: Equatable {
        case onAppear
        case logoutButtonTapped
        case logoutResponse(Result<EquatableVoid, AuthError>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case logoutSucceeded
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
                        try await authClient.logout()
                        await send(.logoutResponse(.success(EquatableVoid())))
                    } catch {
                        await send(.logoutResponse(.failure(mapAuthError(error))))
                    }
                }

            case .logoutResponse(.success):
                state.isLoading = false
                state.userID = nil
                return .send(.delegate(.logoutSucceeded))

            case let .logoutResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = "로그아웃에 실패했습니다."
                if error == .unauthorized {
                    return .send(.delegate(.sessionExpired))
                }
                return .none

            case .delegate:
                return .none
            }
        }
        .logged(as: Self.self)
    }
}

private func mapAuthError(_ error: Error) -> AuthError {
    error as? AuthError ?? .unknown
}
