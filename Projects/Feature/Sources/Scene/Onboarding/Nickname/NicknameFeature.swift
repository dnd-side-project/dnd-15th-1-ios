import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct NicknameFeature {
    /// 시안에 프로필 아이콘 선택이 없어 서버 계약상 필요한 값만 고정으로 보낸다
    static let iconID = 1

    /// 표시 순서 겸 필수 동의 항목
    static let requiredTerms: [TermsType] = [.service, .privacy]

    @ObservableState
    public struct State: Equatable {
        public var nickname: String
        public var isSubmitting: Bool
        public var inlineError: String?
        public var toast: ToastState?
        public var isTermsSheetPresented: Bool
        public var agreedTerms: Set<TermsType>
        public var presentedTerms: TermsType?

        public init(
            nickname: String = "",
            isSubmitting: Bool = false,
            inlineError: String? = nil,
            toast: ToastState? = nil,
            isTermsSheetPresented: Bool = true,
            agreedTerms: Set<TermsType> = [],
            presentedTerms: TermsType? = nil
        ) {
            self.nickname = nickname
            self.isSubmitting = isSubmitting
            self.inlineError = inlineError
            self.toast = toast
            self.isTermsSheetPresented = isTermsSheetPresented
            self.agreedTerms = agreedTerms
            self.presentedTerms = presentedTerms
        }

        public var trimmedNickname: String {
            nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var isNextEnabled: Bool {
            (1...6).contains(trimmedNickname.count) && !isSubmitting
        }

        public var lengthError: String? {
            trimmedNickname.count > 6 ? "최대 6글자 내로 입력해주세요" : nil
        }

        public var isTermsAgreeEnabled: Bool {
            agreedTerms.isSuperset(of: NicknameFeature.requiredTerms)
        }
    }

    public enum Action: Equatable {
        case onAppear
        case nicknameChanged(String)
        case nextButtonTapped
        case updateNicknameResponse(Result<UserProfile, ProfileError>)
        case termsToggled(TermsType)
        case termsDetailTapped(TermsType)
        case dismissTermsDetail
        case termsAgreeButtonTapped
        case dismissToast
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case nicknameConfirmed(UserProfile)
            case sessionExpired
        }
    }

    @Dependency(\.profileClient) var profileClient

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
            case let .nicknameChanged(nickname):
                state.nickname = nickname
                state.inlineError = nil
                return .none
            case .nextButtonTapped:
                return nextButtonTapped(state: &state)
            case let .updateNicknameResponse(result):
                return updateNicknameResponse(result, state: &state)
            case let .termsToggled(terms):
                return termsToggled(terms, state: &state)
            case let .termsDetailTapped(terms):
                return termsDetailTapped(terms, state: &state)
            case .dismissTermsDetail:
                state.presentedTerms = nil
                return .none
            case .termsAgreeButtonTapped:
                guard state.isTermsAgreeEnabled else { return .none }
                state.isTermsSheetPresented = false
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

private extension NicknameFeature {
    func nextButtonTapped(state: inout State) -> Effect<Action> {
        guard state.isNextEnabled else { return .none }
        let nickname = state.trimmedNickname
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

    func termsToggled(
        _ terms: TermsType,
        state: inout State
    ) -> Effect<Action> {
        if state.agreedTerms.contains(terms) {
            state.agreedTerms.remove(terms)
        } else {
            state.agreedTerms.insert(terms)
        }
        return .none
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
