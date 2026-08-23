import Domain
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
            case accountWithdrawn
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
            return handleMyPage(delegate)
        case let .home(.delegate(delegate)):
            return handleHome(state: &state, delegate: delegate)
        case let .map(.delegate(delegate)):
            return handleMap(state: &state, delegate: delegate)
        case let .explore(.delegate(delegate)):
            return handleExplore(state: &state, delegate: delegate)
        case .home, .explore, .map, .myPage, .delegate:
            return .none
        }
    }

    private func handleMyPage(_ delegate: MyPageFeature.Action.Delegate) -> Effect<Action> {
        switch delegate {
        case .logoutSucceeded:
            return .send(.delegate(.logoutSucceeded))
        case .accountWithdrawn:
            return .send(.delegate(.accountWithdrawn))
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }

    private func handleHome(
        state: inout State,
        delegate: HomeFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        case .showAllSavedPlaces:
            // 전체보기는 필터 없는 전체 상태로 지도를 연다
            state.selectedTab = .map
            return .send(.map(.showAllSaved))
        case let .showContentDetail(id):
            return presentContentDetail(state: &state, id: id)
        case let .showPlaceDetail(place):
            // 장소 상세는 지도 탭에서 연다. 닫아도 지도 탭에 머무른다(전체보기와 동일)
            state.selectedTab = .map
            return .send(.map(.presentPlaceDetail(place)))
        }
    }

    private func handleMap(
        state: inout State,
        delegate: MapFlowFeature.Action.Delegate
    ) -> Effect<Action> {
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
    }

    private func handleExplore(
        state: inout State,
        delegate: ExploreFeature.Action.Delegate
    ) -> Effect<Action> {
        switch delegate {
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        case let .showContentDetail(id):
            return presentContentDetail(state: &state, id: id)
        case let .showPlaceDetail(place, query):
            return presentSearchPlaceDetail(state: &state, place: place, query: query)
        }
    }

    /// 지금 탭을 기억해 두고 지도 탭으로 옮겨 게시글 상세를 연다
    private func presentContentDetail(state: inout State, id: String) -> Effect<Action> {
        state.contentReturnTab = state.selectedTab
        state.selectedTab = .map
        return .send(.map(.presentContentDetail(id)))
    }

    /// 지금 탭을 기억해 두고 지도 탭으로 옮겨 검색 장소 상세를 연다. 닫으면 그 탭으로 돌아온다
    private func presentSearchPlaceDetail(state: inout State, place: Place, query: String) -> Effect<Action> {
        state.contentReturnTab = state.selectedTab
        state.selectedTab = .map
        return .send(.map(.presentSearchPlaceDetail(place, query: query)))
    }
}
