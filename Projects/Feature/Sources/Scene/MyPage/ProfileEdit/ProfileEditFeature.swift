import Domain
import Foundation
import SharedDesignSystem
import ThirdParty

@Reducer
public struct ProfileEditFeature {
    /// 고를 수 있는 프로필 아이콘 ID
    static let iconIDs = [1, 2, 3, 4, 5]
    static let maxNicknameLength = 6
    static let maxInputLength = 7

    @ObservableState
    public struct State: Equatable {
        var nickname: String
        var selectedIconID: Int
        var isSaving: Bool
        var toast: ToastState?

        // 1~6글자면서 저장 중이 아닐 때 완료 가능
        var isDoneEnabled: Bool {
            !isSaving && (1...ProfileEditFeature.maxNicknameLength).contains(nickname.count)
        }

        // 6글자 초과 시 안내. 입력은 7까지 받고 여기서 알려준다
        var lengthError: String? {
            nickname.count > ProfileEditFeature.maxNicknameLength
                ? "최대 6글자 내로 입력해주세요"
                : nil
        }

        public init(
            nickname: String = "",
            selectedIconID: Int = 1,
            isSaving: Bool = false,
            toast: ToastState? = nil
        ) {
            self.nickname = ProfileEditFeature.sanitizedNickname(nickname)
            self.selectedIconID = selectedIconID
            self.isSaving = isSaving
            self.toast = toast
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case closeTapped
        case iconSelected(Int)
        case doneTapped
        case saveSucceeded(nickname: String, iconID: Int)
        case saveFailed(ProfileError)
        case dismissToast
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case dismiss
            /// 저장 성공. 상위(마이페이지)가 표시값을 갱신하고 닫는다
            case saved(nickname: String, iconID: Int)
            /// 세션 만료. 상위로 올려 로그인으로 보낸다
            case sessionExpired
        }
    }

    @Dependency(\.profileClient) var profileClient

    // 공백 제거 후 최대 입력 길이로 자른다
    static func sanitizedNickname(_ nickname: String) -> String {
        String(nickname.filter { !$0.isWhitespace }.prefix(maxInputLength))
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .closeTapped:
                return .send(.delegate(.dismiss))

            case let .iconSelected(id):
                state.selectedIconID = id
                return .none

            case .doneTapped:
                guard state.isDoneEnabled else { return .none }
                state.isSaving = true
                return save(nickname: state.nickname, iconID: state.selectedIconID)

            case let .saveSucceeded(nickname, iconID):
                state.isSaving = false
                return .send(.delegate(.saved(nickname: nickname, iconID: iconID)))

            case let .saveFailed(error):
                state.isSaving = false
                // 세션 만료는 로그인으로, 나머지는 토스트로 알리고 시트는 유지
                if error == .unauthorized {
                    return .send(.delegate(.sessionExpired))
                }
                state.toast = Self.toastState(for: error)
                return .none

            case .dismissToast:
                state.toast = nil
                return .none

            case .binding, .delegate:
                return .none
            }
        }
    }

    // PATCH 후 서버가 돌려준 값으로 확정
    private func save(nickname: String, iconID: Int) -> Effect<Action> {
        .run { [profileClient] send in
            do {
                let profile = try await profileClient.updateProfile(nickname, iconID)
                await send(.saveSucceeded(nickname: profile.nickname, iconID: profile.iconID))
            } catch {
                await send(.saveFailed(error as? ProfileError ?? .unknown))
            }
        }
    }

    // 401 은 위에서 로그인으로 보내므로 여기 안 온다. 나머지는 네트워크/그 외로만 나눈다
    private static func toastState(for error: ProfileError) -> ToastState {
        switch error {
        case .network:
            .error("네트워크 연결을 확인해 주세요.")
        case .invalidNickname, .unauthorized, .unknown:
            .error("저장에 실패했어요. 잠시 후 다시 시도해 주세요.")
        }
    }
}
