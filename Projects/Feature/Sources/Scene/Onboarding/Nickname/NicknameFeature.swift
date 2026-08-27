import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct NicknameFeature {
    /// 시안에 프로필 아이콘 선택이 없어 서버 계약상 필요한 값만 고정으로 보낸다
    static let iconID = 1

    /// 시트가 그리는 필수 동의 항목과 그 표시 순서
    static let requiredTerms: [TermsType] = [.service, .privacy]

    /// 통과 기준
    static let maxNicknameLength = 6

    /// 초과 사실을 보여주려고 기준보다 한 글자만 더 받는다
    static let maxInputLength = 7

    /// 공백은 애초에 담지 않고 길이도 여기서 잘라 State.nickname 을 항상 검증 가능한 값으로 둔다
    static func sanitizedNickname(_ nickname: String) -> String {
        String(nickname.filter { !$0.isWhitespace }.prefix(maxInputLength))
    }

    @ObservableState
    public struct State: Equatable {
        public var nickname: String
        public var isSubmitting: Bool
        public var inlineError: String?
        public var toast: ToastState?
        public var isTermsSheetPresented: Bool
        public var presentedTerms: TermsType?

        public init(
            nickname: String = "",
            isSubmitting: Bool = false,
            inlineError: String? = nil,
            toast: ToastState? = nil,
            isTermsSheetPresented: Bool = true,
            presentedTerms: TermsType? = nil
        ) {
            self.nickname = NicknameFeature.sanitizedNickname(nickname)
            self.isSubmitting = isSubmitting
            self.inlineError = inlineError
            self.toast = toast
            self.isTermsSheetPresented = isTermsSheetPresented
            self.presentedTerms = presentedTerms
        }

        public var isNextEnabled: Bool {
            (1...NicknameFeature.maxNicknameLength).contains(nickname.count) && !isSubmitting
        }

        public var lengthError: String? {
            nickname.count > NicknameFeature.maxNicknameLength ? "최대 6글자 내로 입력해주세요" : nil
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case nextButtonTapped
        case updateNicknameResponse(Result<UserProfile, ProfileError>)
        case termsDetailTapped(TermsType)
        case dismissTermsDetail
        case termsAgreeButtonTapped
        case backButtonTapped
        case dismissToast
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case nicknameConfirmed(UserProfile)
            /// 닉네임은 스택의 첫 화면이라 뒤로 가면 로그인으로 내려간다
            case back
            case sessionExpired
        }
    }

    @Dependency(\.profileClient) var profileClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
    }
}

private extension NicknameFeature {
    func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        // 입력칸이 이미 걸러낸 값만 올려보내지만 붙여넣기·초기값 같은 다른 경로가 있어 여기서 한 번 더 다듬는다
        case .binding(\.nickname):
            state.nickname = Self.sanitizedNickname(state.nickname)
            state.inlineError = nil
            return .none
        case .binding:
            return .none
        case .nextButtonTapped:
            return nextButtonTapped(state: &state)
        case let .updateNicknameResponse(result):
            return updateNicknameResponse(result, state: &state)
        case let .termsDetailTapped(terms):
            return termsDetailTapped(terms, state: &state)
        case .dismissTermsDetail:
            state.presentedTerms = nil
            return .none
        case .termsAgreeButtonTapped:
            state.isTermsSheetPresented = false
            return .none
        case .backButtonTapped:
            return backButtonTapped(state: &state)
        case .dismissToast:
            state.toast = nil
            return .none
        case .delegate:
            return .none
        }
    }

    /// 제출이 도는 중에는 물러나지 않는다. 응답이 화면 없는 곳으로 떨어진다
    func backButtonTapped(state: inout State) -> Effect<Action> {
        guard !state.isSubmitting else { return .none }
        state.toast = nil
        return .send(.delegate(.back))
    }

    func nextButtonTapped(state: inout State) -> Effect<Action> {
        guard state.isNextEnabled else { return .none }
        let nickname = state.nickname
        let iconID = Self.iconID
        state.isSubmitting = true
        state.inlineError = nil
        state.toast = nil
        return .run { [profileClient] send in
            do {
                let profile = try await profileClient.updateNickname(nickname, iconID)
                await send(.updateNicknameResponse(.success(profile)))
            } catch {
                await send(.updateNicknameResponse(.failure(mapProfileError(error))))
            }
        }
    }

    func updateNicknameResponse(
        _ result: Result<UserProfile, ProfileError>,
        state: inout State
    ) -> Effect<Action> {
        state.isSubmitting = false
        switch result {
        case let .success(profile):
            return .send(.delegate(.nicknameConfirmed(profile)))
        case let .failure(error):
            return handleUpdateNicknameFailure(error, state: &state)
        }
    }

    func handleUpdateNicknameFailure(
        _ error: ProfileError,
        state: inout State
    ) -> Effect<Action> {
        switch error {
        case .invalidNickname:
            state.inlineError = "사용할 수 없는 닉네임이에요"
            return .none
        case .network:
            state.toast = .error("네트워크 연결을 확인해 주세요.")
            return .none
        case .unauthorized:
            return .send(.delegate(.sessionExpired))
        case .unknown:
            state.toast = .error("잠시 후 다시 시도해 주세요.")
            return .none
        }
    }

    func termsDetailTapped(
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

private func mapProfileError(_ error: Error) -> ProfileError {
    error as? ProfileError ?? .unknown
}
