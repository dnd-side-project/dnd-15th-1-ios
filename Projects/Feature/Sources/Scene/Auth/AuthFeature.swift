import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct AuthFeature {
    @ObservableState
    public struct State: Equatable {
        public var isLoading = false
        public var loadingProvider: AuthProvider?
        public var toast: ToastState?
        public var presentedTerms: TermsType?

        public init(
            isLoading: Bool = false,
            loadingProvider: AuthProvider? = nil,
            toast: ToastState? = nil,
            presentedTerms: TermsType? = nil
        ) {
            self.isLoading = isLoading
            self.loadingProvider = loadingProvider
            self.toast = toast
            self.presentedTerms = presentedTerms
        }
    }

    public enum Action: Equatable {
        case onAppear
        case loginButtonTapped(AuthProvider)
        case loginResponse(Result<AuthSession, AuthError>)
        case termsLinkTapped(TermsType)
        case dismissTerms
        case dismissToast
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
            case let .loginButtonTapped(provider):
                return loginButtonTapped(provider, state: &state)
            case let .loginResponse(result):
                return loginResponse(result, state: &state)
            case let .termsLinkTapped(terms):
                return termsLinkTapped(terms, state: &state)
            case .dismissTerms:
                state.presentedTerms = nil
                return .none
            case .dismissToast:
                state.toast = nil
                return .none
            case .delegate:
                return .none
            }
        }
    }
}

private extension AuthFeature {
    func loginButtonTapped(
        _ provider: AuthProvider,
        state: inout State
    ) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.loadingProvider = provider
        state.toast = nil
        return .run { [authClient] send in
            do {
                let session = try await authClient.login(provider)
                await send(.loginResponse(.success(session)))
            } catch {
                await send(.loginResponse(.failure(mapAuthError(error))))
            }
        }
    }

    func loginResponse(
        _ result: Result<AuthSession, AuthError>,
        state: inout State
    ) -> Effect<Action> {
        state.isLoading = false
        state.loadingProvider = nil
        switch result {
        case let .success(session):
            return .send(.delegate(.loginSucceeded(userID: session.userID)))
        case let .failure(error):
            state.toast = toastState(for: error)
            return .none
        }
    }

    func termsLinkTapped(
        _ terms: TermsType,
        state: inout State
    ) -> Effect<Action> {
        guard let url = terms.url, SupportedWebURL.isSupported(url) else {
            return .none
        }
        state.presentedTerms = terms
        return .none
    }
}

private func mapAuthError(_ error: Error) -> AuthError {
    error as? AuthError ?? .unknown
}

private func toastState(for error: AuthError) -> ToastState? {
    switch error {
    case .cancelled:
        return nil
    case .network:
        return .error("네트워크 연결을 확인해 주세요.")
    case .loginFailed:
        return .error("로그인에 실패했습니다.")
    case .unauthorized, .storage, .unknown:
        return .error("잠시 후 다시 시도해 주세요.")
    }
}
