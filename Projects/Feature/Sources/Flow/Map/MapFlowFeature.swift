import Domain
import Foundation
import ThirdParty

/// 지도 탭의 화면 스택. 지도가 root 이고 목적지 화면이 그 위로 쌓인다.
///
/// 화면을 안 그린다. 경로와 자식만 갖는다
@Reducer
public struct MapFlowFeature {
    /// 지도(root) 위로 쌓이는 화면. 각 case 의 화면은 담당 Cycle 이 자기 PR 에서 채운다
    public enum Route: Hashable {
        /// Cycle 7 (미배정)
        case postDetail(String)
        /// Cycle 3 (DND-50)
        case search
        /// Cycle 4 (DND-51)
        case course
        /// Cycle 4 (DND-51)
        case coursePlacePick
    }

    @ObservableState
    public struct State: Equatable {
        public var map: MapFeature.State
        public var course: CourseFeature.State?
        public var path: [Route]
        public var placeSearch: PlaceSearchFeature.State?

        /// 핀·행·검색에서 뜬 장소 상세. 시트 표시는 `MapFlowView` 가 한다
        @Presents public var detail: PlaceDetailFeature.State?

        /// 행 메뉴 `수정` 으로 뜬 별칭 지정 시트
        @Presents public var alias: PlaceAliasFeature.State?

        /// 장소 상세에서 뜬 게시글 상세. 시트 표시는 `MapFlowView` 가 한다
        @Presents public var postDetail: PostDetailFeature.State?

        public init(
            map: MapFeature.State = MapFeature.State(),
            course: CourseFeature.State? = nil,
            path: [Route] = [],
            placeSearch: PlaceSearchFeature.State? = nil,
            detail: PlaceDetailFeature.State? = nil,
            alias: PlaceAliasFeature.State? = nil,
            postDetail: PostDetailFeature.State? = nil
        ) {
            self.map = map
            self.course = course
            self.path = path
            self.placeSearch = placeSearch
            self.detail = detail
            self.alias = alias
            self.postDetail = postDetail
        }
    }

    public enum Action: Equatable {
        case pathChanged([Route])
        case map(MapFeature.Action)
        case course(CourseFeature.Action)
        case placeSearch(PlaceSearchFeature.Action)
        case detail(PresentationAction<PlaceDetailFeature.Action>)
        case alias(PresentationAction<PlaceAliasFeature.Action>)
        case postDetail(PresentationAction<PostDetailFeature.Action>)
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
            .ifLet(\.course, action: \.course) {
                CourseFeature()
            }
            .ifLet(\.$detail, action: \.detail) {
                PlaceDetailFeature()
            }
            .ifLet(\.$alias, action: \.alias) {
                PlaceAliasFeature()
            }
            .ifLet(\.$postDetail, action: \.postDetail) {
                PostDetailFeature()
            }
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
            if !path.contains(.course), !path.contains(.coursePlacePick) {
                state.course = nil
            }
            return .none
        case let .map(.delegate(delegate)):
            return handle(mapDelegate: delegate, state: &state)
        case let .course(.delegate(delegate)):
            return handle(courseDelegate: delegate, state: &state)
        case let .placeSearch(.delegate(delegate)):
            return handle(searchDelegate: delegate, state: &state)
        case .detail, .alias, .postDetail:
            return handleChild(state: &state, action: action)
        case .map, .course, .placeSearch, .delegate:
            return .none
        }
    }
}

private extension MapFlowFeature {
    /// 지도가 올린 신호로 시트나 경로를 연다. 화면 이동이 아닌 것은 여기서 삼킨다
    func handle(
        mapDelegate: MapFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch mapDelegate {
        case let .placeDetailRequested(id):
            presentDetail(state: &state, id: id)
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
            // 지난 진입의 날짜·장소를 물려받으면 안 된다
            state.course = CourseFeature.State()
            state.path.append(.course)
            return .none
        case let .aliasRequested(id):
            if let saved = state.map.places.first(where: { $0.id == id }) {
                state.alias = PlaceAliasFeature.State(savedPlace: saved)
            }
            return .none
        case .deleteRequested:
            // PlaceClient 에 삭제 계약이 없다. 계약이 생겨도 데이터 갱신이라 path 를 안 쓴다
            return .none
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }

    func handle(
        courseDelegate: CourseFeature.Action.Delegate,
        state: inout State
    ) -> Effect<Action> {
        switch courseDelegate {
        case .placePickRequested:
            state.path.append(.coursePlacePick)
            return .none
        case .dismissed:
            var next = state.path
            // 코스 화면이 스스로 닫는 신호라, 맨 위가 코스 경로일 때만 뺀다
            if let last = next.last, last == .course || last == .coursePlacePick {
                next.removeLast()
            }
            return .send(.pathChanged(next))
        case .buildRequested:
            // Cycle 5 (DND-52) 가 코스 결과 화면을 붙일 때까지 삼킨다
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
        case let .placeSelected(place):
            // 고른 장소 하나를 지도에 올리고 시트만 상세로 바꾼다. 상세는 밀린 화면이 아니다
            presentDetail(state: &state, place: place)
            return .concatenate(
                .send(.pathChanged([])),
                .send(.map(.searchResultsApplied(query: place.name, places: [place])))
            )
        case .sessionExpired:
            return .send(.delegate(.sessionExpired))
        }
    }

    func handleChild(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .alias(.presented(.delegate(.saved(id, alias)))):
            state.alias = nil
            return .send(.map(.aliasSaved(id: id, alias: alias)))

        case .alias(.presented(.delegate(.cancelled))), .alias(.dismiss):
            state.alias = nil
            return .none

        case let .detail(.presented(.delegate(.contentSelected(id)))):
            // 장소 상세를 닫지 않는다. 게시글을 닫으면 그 자리로 돌아가야 한다
            state.postDetail = PostDetailFeature.State(contentID: id)
            // 화면 등장에 안 기댄다. 내려가던 시트를 도로 올리면 등장이 안 온다
            return .send(.postDetail(.presented(.onAppear)))

        case .detail(.presented(.delegate(.closed))), .detail(.dismiss):
            dismissDetail(state: &state)
            return .none

        case .postDetail(.presented(.delegate(.closeRequested))), .postDetail(.dismiss):
            state.postDetail = nil
            return .none

        case .postDetail(.presented(.delegate(.sessionExpired))):
            return .send(.delegate(.sessionExpired))

        case .postDetail(.presented(.delegate(.placeSelected))),
             .postDetail(.presented(.delegate(.instagramRequested))):
            // 장소 상세로 가는 길은 이 Cycle 밖이다. 인스타 외부 전환도 밖이다
            return .none

        case .detail, .alias, .postDetail:
            // 북마크·지도는 받는 쪽이 아직 없다. 삼킨다
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    /// 저장 모드면 저장 목록, 검색 모드면 검색 결과에서 찾는다. 없으면 시트를 안 연다
    func presentDetail(state: inout State, id: String) {
        switch state.map.mode {
        case .saved:
            if let saved = state.map.places.first(where: { $0.id == id }) {
                presentDetail(state: &state, savedPlace: saved)
            }
        case .searchResult:
            if let place = state.map.searchResults.first(where: { $0.id == id }) {
                presentDetail(state: &state, place: place)
            }
        }
    }

    func presentDetail(state: inout State, savedPlace: SavedPlace) {
        var detail = PlaceDetailFeature.State(savedPlace: savedPlace)
        // 검색 모드에서 끈 북마크가 저장 목록에서 다시 켜져 보이면 안 된다. 두 길이 같은 집합을 본다
        detail.isBookmarked = state.map.bookmarkedPlaceIDs.contains(savedPlace.id)
        state.detail = detail
        state.map.selectedPlace = MapFeature.State.SelectedPlace(
            id: savedPlace.id,
            coordinate: savedPlace.place.coordinate
        )
        // 게시글 상세가 떠 있으면 지운다. 두 상세가 동시에 살아 있으면 안 된다
        state.postDetail = nil
    }

    func presentDetail(state: inout State, place: Place) {
        var detail = PlaceDetailFeature.State(place: place)
        detail.isBookmarked = state.map.bookmarkedPlaceIDs.contains(place.id)
        state.detail = detail
        state.map.selectedPlace = MapFeature.State.SelectedPlace(
            id: place.id,
            coordinate: place.coordinate
        )
        // 게시글 상세가 떠 있으면 지운다. 두 상세가 동시에 살아 있으면 안 된다
        state.postDetail = nil
    }

    func dismissDetail(state: inout State) {
        state.detail = nil
        state.map.selectedPlace = nil
    }
}
