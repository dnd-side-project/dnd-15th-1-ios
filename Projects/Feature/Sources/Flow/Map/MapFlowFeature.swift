import Foundation
import ThirdParty

/// 지도 탭의 화면 스택. 지도가 root 이고 목적지 화면이 그 위로 쌓인다.
///
/// 화면을 안 그린다. 경로와 자식만 갖는다
@Reducer
public struct MapFlowFeature {
    /// 지도(root) 위로 쌓이는 화면. 각 case 의 화면은 담당 Cycle 이 자기 PR 에서 채운다
    public enum Route: Hashable {
        /// Cycle 2 (DND-49)
        case placeDetail(String)
        /// Cycle 7 (미배정)
        case postDetail(String)
        /// Cycle 3 (DND-50)
        case search
        /// Cycle 4 (DND-51)
        case course
    }

    @ObservableState
    public struct State: Equatable {
        public var map: MapFeature.State
        public var path: [Route]
        public var placeSearch: PlaceSearchFeature.State?

        public init(
            map: MapFeature.State = MapFeature.State(),
            path: [Route] = [],
            placeSearch: PlaceSearchFeature.State? = nil
        ) {
            self.map = map
            self.path = path
            self.placeSearch = placeSearch
        }
    }

    public enum Action: Equatable {
        case pathChanged([Route])
        case map(MapFeature.Action)
        case placeSearch(PlaceSearchFeature.Action)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 세션 만료. RootFlow 까지 올라가 로그인으로 되돌린다
            case sessionExpired
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.map, action: \.map) {
            MapFeature()
        }
        Reduce(core)
            .ifLet(\.placeSearch, action: \.placeSearch) {
                PlaceSearchFeature()
            }
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .pathChanged(path):
            state.path = path
            if !path.contains(.search) {
                state.placeSearch = nil
            }
            return .none
        case let .map(.delegate(delegate)):
            return handle(mapDelegate: delegate, state: &state)
        case let .placeSearch(.delegate(delegate)):
            return handle(searchDelegate: delegate, state: &state)
        case .placeSearch:
            return .none
        case .map, .delegate:
            return .none
        }
    }
}

private extension MapFlowFeature {
    /// 지도가 올린 신호를 경로로 옮긴다. 화면 이동이 아닌 것은 여기서 삼킨다
    func handle(
        mapDelegate: MapFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch mapDelegate {
        case let .placeSelected(id):
            state.path.append(.placeDetail(id))
            return .none
        case .searchRequested:
            state.placeSearch = PlaceSearchFeature.State()
            state.path.append(.search)
            return .none
        case let .searchReopenRequested(query):
            state.placeSearch = PlaceSearchFeature.State(query: query)
            if !state.path.contains(.search) {
                state.path.append(.search)
            }
            return .none
        case .courseRequested:
            state.path.append(.course)
            return .none
        case .editRequested, .deleteRequested:
            // PlaceClient 에 수정·삭제 계약이 없다. 계약이 생겨도 데이터 갱신이라 path 를 안 쓴다
            return .none
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }

    func handle(
        searchDelegate: PlaceSearchFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch searchDelegate {
        case .dismissed:
            // 검색바 X 와 같이 저장 장소 모드로 돌아가 뒤로가기 루프를 끊는다
            return .merge(
                .send(.pathChanged([])),
                .send(.map(.searchClearTapped))
            )
        case let .searchConfirmed(query, places):
            return .merge(
                .send(.pathChanged([])),
                .send(.map(.searchResultsApplied(query: query, places: places)))
            )
        case let .placeSelected(id):
            // 장소 상세는 Cycle 2 (DND-49). 경로만 밀어 둔다
            state.path = [.placeDetail(id)]
            return .none
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }
}
