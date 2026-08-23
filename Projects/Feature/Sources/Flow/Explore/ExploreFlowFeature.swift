import Domain
import Foundation
import ThirdParty

/// 탐색 탭의 화면 스택. 탐색이 root 이고 검색이 그 위로 쌓인다.
///
/// 화면을 안 그린다. 경로와 자식만 갖는다
@Reducer
public struct ExploreFlowFeature {
    /// 탐색(root) 위로 쌓이는 화면.
    public enum Route: Hashable {
        case search
    }

    @ObservableState
    public struct State: Equatable {
        public var explore: ExploreFeature.State
        public var search: SearchFeature.State?
        public var path: [Route]

        public init(
            explore: ExploreFeature.State = ExploreFeature.State(),
            search: SearchFeature.State? = nil,
            path: [Route] = []
        ) {
            self.explore = explore
            self.search = search
            self.path = path
        }
    }

    public enum Action: Equatable {
        case pathChanged([Route])
        case explore(ExploreFeature.Action)
        case search(SearchFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 세션 만료. RootFlow 까지 올라가 로그인으로 되돌린다
            case sessionExpired
            /// 카드 탭. MainTab 이 지도 탭으로 옮겨 상세를 연다
            case showContentDetail(String)
            /// 장소 결과 탭. MainTab 이 지도 탭으로 옮겨 장소 상세를 연다
            case showPlaceDetail(Place, query: String)
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.explore, action: \.explore) {
            ExploreFeature()
        }
        Reduce(core)
            .ifLet(\.search, action: \.search) {
                SearchFeature()
            }
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .pathChanged(path):
            state.path = path
            // 스택에서 빠지면 스토어를 내려 다음 진입이 새 상태로 시작하게 한다
            if !path.contains(.search) { state.search = nil }
            return .none

        case let .explore(.delegate(delegate)):
            return handle(exploreDelegate: delegate, state: &state)

        case let .search(.delegate(delegate)):
            return handle(searchDelegate: delegate)

        case .explore, .search, .delegate:
            return .none
        }
    }
}

private extension ExploreFlowFeature {
    func handle(
        exploreDelegate: ExploreFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch exploreDelegate {
        case .searchRequested:
            state.search = SearchFeature.State()
            state.path = [.search]
            return .none
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        case let .showContentDetail(id):
            return .send(.delegate(.showContentDetail(id)))
        case let .showPlaceDetail(place, query):
            return .send(.delegate(.showPlaceDetail(place, query: query)))
        }
    }

    /// 검색 결과에서 고른 것도 탐색 카드와 같은 길로 올린다
    func handle(searchDelegate: SearchFeature.Action.Delegate) -> Effect<Action> {
        switch searchDelegate {
        case let .showContentDetail(id):
            return .send(.delegate(.showContentDetail(id)))
        case let .showPlaceDetail(place, query):
            return .send(.delegate(.showPlaceDetail(place, query: query)))
        }
    }
}
