import Domain
import ThirdParty

/// 공지 한 건을 읽는 화면. 목록에서 받은 값만 그리고 서버를 다시 안 부른다
@Reducer
public struct NoticeDetailFeature {
    @ObservableState
    public struct State: Equatable {
        public var notice: Notice

        public init(notice: Notice) {
            self.notice = notice
        }
    }

    public enum Action: Equatable {
        case backButtonTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case back
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce(core)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .backButtonTapped:
            return .send(.delegate(.back))

        case .delegate:
            return .none
        }
    }
}
