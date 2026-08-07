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
            case unauthorized
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
                case .unauthorized:
                    return .send(.delegate(.unauthorized))
                }
            case .home, .explore, .map, .myPage, .delegate:
                return .none
            }
        }
    }
}
