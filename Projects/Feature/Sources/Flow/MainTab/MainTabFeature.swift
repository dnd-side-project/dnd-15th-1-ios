import Foundation
import ThirdParty

@Reducer
public struct MainTabFeature {
    public enum Tab: String, Equatable, Sendable, CaseIterable {
        case home
        case explore
        case map
        case myPage
    }

    @ObservableState
    public struct State: Equatable {
        public var selectedTab: Tab
        public var home: HomeFeature.State
        public var explore: ExploreFeature.State
        public var map: MapFeature.State
        public var myPage: MyPageFeature.State

        public init(
            selectedTab: Tab = .home,
            home: HomeFeature.State = HomeFeature.State(),
            explore: ExploreFeature.State = ExploreFeature.State(),
            map: MapFeature.State = MapFeature.State(),
            myPage: MyPageFeature.State = MyPageFeature.State()
        ) {
            self.selectedTab = selectedTab
            self.home = home
            self.explore = explore
            self.map = map
            self.myPage = myPage
        }
    }

    public enum Action: Equatable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case explore(ExploreFeature.Action)
        case map(MapFeature.Action)
        case myPage(MyPageFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case logoutSucceeded
            case sessionExpired
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.home, action: \.home) {
            HomeFeature()
        }
        Scope(state: \.explore, action: \.explore) {
            ExploreFeature()
        }
        Scope(state: \.map, action: \.map) {
            MapFeature()
        }
        Scope(state: \.myPage, action: \.myPage) {
            MyPageFeature()
        }
        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            case let .myPage(.delegate(delegate)):
                switch delegate {
                case .logoutSucceeded:
                    return .send(.delegate(.logoutSucceeded))
                case .sessionExpired:
                    return .send(.delegate(.sessionExpired))
                }
            case let .home(.delegate(delegate)):
                switch delegate {
                case .sessionExpired:
                    return .send(.delegate(.sessionExpired))
                }
            case let .map(.delegate(delegate)):
                return handle(mapDelegate: delegate)
            case .home, .explore, .map, .myPage, .delegate:
                return .none
            }
        }
        .logged(as: Self.self)
    }

    /// 지도가 올린 신호를 가른다. 받는 쪽이 아직 없는 것은 여기서 삼킨다.
    ///
    /// 리듀서 본문에 그대로 두면 `closure_body_length` 를 넘긴다
    private func handle(mapDelegate: MapFeature.Action.Delegate) -> Effect<Action> {
        switch mapDelegate {
        case .placeSelected:
            // 장소 상세 시트는 Cycle 2 (DND-49)
            return .none
        case .searchRequested:
            // 검색 화면은 Cycle 3 (DND-50)
            return .none
        case .courseRequested:
            // 코스 흐름은 Cycle 4 (DND-51)
            return .none
        case .editRequested, .deleteRequested:
            // PlaceClient 에 수정·삭제 계약이 없다. 계약이 생기면 여기서 받는다
            return .none
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }
}
