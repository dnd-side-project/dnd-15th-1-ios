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
        public var map: MapFlowFeature.State
        public var myPage: MyPageFeature.State

        /// 게시글 상세를 열기 직전 탭. 상세를 닫으면 이 탭으로 되돌린다
        public var contentReturnTab: Tab?

        public init(
            selectedTab: Tab = .home,
            home: HomeFeature.State = HomeFeature.State(),
            explore: ExploreFeature.State = ExploreFeature.State(),
            map: MapFlowFeature.State = MapFlowFeature.State(),
            myPage: MyPageFeature.State = MyPageFeature.State(),
            contentReturnTab: Tab? = nil
        ) {
            self.selectedTab = selectedTab
            self.home = home
            self.explore = explore
            self.map = map
            self.myPage = myPage
            self.contentReturnTab = contentReturnTab
        }
    }

    public enum Action: Equatable {
        case tabSelected(Tab)
        case home(HomeFeature.Action)
        case explore(ExploreFeature.Action)
        case map(MapFlowFeature.Action)
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
            MapFlowFeature()
        }
        Scope(state: \.myPage, action: \.myPage) {
            MyPageFeature()
        }
        Reduce(core)
        .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
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
            case .showAllSavedPlaces:
                state.selectedTab = .map
                return .none
            case let .showContentDetail(id):
                return presentContentDetail(state: &state, id: id)
            }
        case let .map(.delegate(delegate)):
            switch delegate {
            case .sessionExpired:
                return .send(.delegate(.sessionExpired))
            case .contentDetailClosed:
                // 게시글을 고르기 전 탭으로 되돌린다
                if let tab = state.contentReturnTab {
                    state.selectedTab = tab
                    state.contentReturnTab = nil
                }
                return .none
            }
        case let .explore(.delegate(delegate)):
            switch delegate {
            case .sessionExpired:
                return .send(.delegate(.sessionExpired))
            case let .showContentDetail(id):
                return presentContentDetail(state: &state, id: id)
            }
        case .home, .explore, .map, .myPage, .delegate:
            return .none
        }
    }

    /// 지금 탭을 기억해 두고 지도 탭으로 옮겨 게시글 상세를 연다
    private func presentContentDetail(state: inout State, id: String) -> Effect<Action> {
        state.contentReturnTab = state.selectedTab
        state.selectedTab = .map
        return .send(.map(.presentContentDetail(id)))
    }
}
