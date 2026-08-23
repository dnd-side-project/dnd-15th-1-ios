import Domain
import Foundation
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

        // 1~6글자면 완료 가능
        var isDoneEnabled: Bool {
            (1...ProfileEditFeature.maxNicknameLength).contains(nickname.count)
        }

        // 6글자 초과 시 안내. 입력은 7까지 받고 여기서 알려준다
        var lengthError: String? {
            nickname.count > ProfileEditFeature.maxNicknameLength
                ? "최대 6글자 내로 입력해주세요"
                : nil
        }

        public init(nickname: String = "", selectedIconID: Int = 1) {
            self.nickname = ProfileEditFeature.sanitizedNickname(nickname)
            self.selectedIconID = selectedIconID
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case closeTapped
        case iconSelected(Int)
        case doneTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case dismiss
            /// 완료. 저장은 상위(마이페이지)가 처리. API 는 이후 연결
            case saved(nickname: String, iconID: Int)
        }
    }

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
                return .send(.delegate(.saved(nickname: state.nickname, iconID: state.selectedIconID)))

            case .binding, .delegate:
                return .none
            }
        }
    }
}
