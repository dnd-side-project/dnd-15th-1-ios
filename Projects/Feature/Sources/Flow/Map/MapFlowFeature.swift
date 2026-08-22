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

        /// 게시글 상세를 다른 탭에서 열어 지도 핀 모드로 들어온 경우. 닫을 때 원래 탭으로 되돌린다
        public var showsContentPins: Bool = false

        /// 탐색 검색에서 장소 상세를 열어 들어온 경우. 상세를 닫으면 원래 탭으로 되돌린다
        public var returnsAfterDetailClose: Bool = false

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
        /// 다른 탭에서 고른 게시글 상세를 지도 위에 연다
        case presentContentDetail(String)
        /// 홈에서 고른 저장 장소 상세를 지도 위에 연다
        case presentPlaceDetail(SavedPlace)
        /// 탐색 검색에서 고른 장소 상세를 지도 위에 연다. 닫으면 원래 탭으로 되돌린다
        case presentSearchPlaceDetail(Place)
        /// 홈 전체보기로 들어온다. 걸린 필터를 풀고 전체를 보여준다
        case showAllSaved
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
            /// 게시글 상세 시트를 닫았다. MainTab 이 게시글을 고르기 전 탭으로 되돌린다
            case contentDetailClosed
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
        case let .presentContentDetail(id):
            // 상세는 시트가 스스로 불러온다. 로드되면 그 places 로 핀을 세운다
            state.showsContentPins = true
            state.postDetail = PostDetailFeature.State(contentID: id)
            // 상세가 뜨는 즉시 저장 시트·코스 버튼을 감추도록 핀 모드로 들어간다. 핀은 로드 후 채운다
            state.map.mode = .content(places: [])
            return .send(.postDetail(.presented(.onAppear)))
        case let .presentPlaceDetail(savedPlace):
            // 저장 장소라 북마크는 켜 둔다. 상세를 닫아도 지도 탭에 머무른다
            state.detail = PlaceDetailFeature.State(savedPlace: savedPlace)
            state.map.selectedPlace = MapFeature.State.SelectedPlace(
                id: savedPlace.id,
                coordinate: savedPlace.place.coordinate
            )
            state.map.camera = .focusing(
                savedPlace.place.coordinate,
                zoomLevel: state.map.camera.zoomLevel
            )
            return .none
        case let .presentSearchPlaceDetail(place):
            // 검색 장소 상세. 닫으면 탐색 탭으로 되돌리도록 표시해 둔다
            state.returnsAfterDetailClose = true
            // 저장 핀·검색 UI 를 감추고 이 장소만 지도에 얹는다
            state.map.mode = .content(places: [place])
            presentDetail(state: &state, place: place)
            state.map.camera = .focusing(place.coordinate, zoomLevel: state.map.camera.zoomLevel)
            return .none
        case .showAllSaved:
            // 어떤 모드에서 불려도 전체 저장 상태가 되도록 저장 목록 모드로 되돌린 뒤 필터를 푼다
            return .merge(
                .send(.map(.searchClearTapped)),
                .send(.map(.filtersReset))
            )
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

        case .detail:
            return handleDetail(state: &state, action: action)

        case let .postDetail(.presented(.delegate(.detailLoaded(detail)))):
            // 다른 탭에서 열어 핀 모드로 들어온 경우에만 상세의 places 로 핀·카메라를 세운다
            guard state.showsContentPins else { return .none }
            return .send(.map(.contentPlacesApplied(places: detail.places.map(place))))

        case .postDetail(.presented(.delegate(.closeRequested))), .postDetail(.dismiss):
            state.postDetail = nil
            guard state.showsContentPins else { return .none }
            // 핀 모드를 풀고 지도를 저장 목록으로 되돌린 뒤, 게시글 고르기 전 탭으로 되돌리도록 올린다
            state.showsContentPins = false
            return .merge(
                .send(.map(.searchClearTapped)),
                .send(.delegate(.contentDetailClosed))
            )

        case .postDetail(.presented(.delegate(.sessionExpired))):
            return .send(.delegate(.sessionExpired))

        case let .postDetail(.presented(.delegate(.placeSelected(id)))):
            // 리스트 아이템 탭도 핀 탭과 똑같이 카메라를 옮기고 그 장소 상세를 얹는다
            focusContentPlaceDetail(state: &state, id: id)
            return .none

        case .alias, .postDetail:
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    /// 장소 상세가 올린 신호 처리. 게시글로 넘어가기·닫기·저장 상태 동기화
    func handleDetail(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case let .detail(.presented(.delegate(.contentSelected(id)))):
            // 장소 상세를 닫지 않는다. 게시글을 닫으면 그 자리로 돌아가야 한다
            state.postDetail = PostDetailFeature.State(contentID: id)
            // 화면 등장에 안 기댄다. 내려가던 시트를 도로 올리면 등장이 안 온다
            return .send(.postDetail(.presented(.onAppear)))

        case .detail(.presented(.delegate(.closed))), .detail(.dismiss):
            dismissDetail(state: &state)
            // 탐색 검색에서 열린 상세면 지도를 저장 목록으로 되돌린 뒤 원래 탭으로 되돌린다
            guard state.returnsAfterDetailClose else { return .none }
            state.returnsAfterDetailClose = false
            return .merge(
                .send(.map(.searchClearTapped)),
                .send(.delegate(.contentDetailClosed))
            )

        case let .detail(.presented(.delegate(.bookmarkToggled(id, isSaved)))):
            // 장소 상세에서 바뀐 저장 상태를 게시글 상세 목록·지도 핀에 맞춘다
            syncPlaceSaved(state: &state, id: id, isSaved: isSaved)
            return .none

        default:
            return .none
        }
    }

    /// 게시글 상세 목록·지도 핀의 저장 상태를 한곳에서 맞춘다
    func syncPlaceSaved(state: inout State, id: String, isSaved: Bool) {
        if isSaved {
            state.postDetail?.savedPlaceIDs.insert(id)
            state.map.bookmarkedPlaceIDs.insert(id)
        } else {
            state.postDetail?.savedPlaceIDs.remove(id)
            state.map.bookmarkedPlaceIDs.remove(id)
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
        case .content:
            // 게시글 핀을 누르면 그 장소 상세를 게시글 상세 위에 얹는다
            if let place = state.map.contentPlaces.first(where: { $0.id == id }) {
                presentContentPlaceDetail(state: &state, place: place)
            }
        }
    }

    /// 리스트에서 고른 장소로 카메라를 옮기고 상세를 연다. 지도에 없는 id 면 무시한다
    func focusContentPlaceDetail(state: inout State, id: String) {
        guard let place = state.map.contentPlaces.first(where: { $0.id == id }) else { return }
        state.map.camera = .focusing(place.coordinate, zoomLevel: state.map.camera.zoomLevel)
        presentContentPlaceDetail(state: &state, place: place)
    }

    /// 게시글 핀을 눌러 장소 상세를 연다. 게시글 상세는 남겨 둬 상세를 닫으면 그 자리로 돌아간다
    func presentContentPlaceDetail(state: inout State, place: Place) {
        var detail = PlaceDetailFeature.State(place: place)
        // 저장 상태는 게시글 상세 목록을 기준으로 물려받는다. 없으면 지도 저장 목록을 본다
        detail.isBookmarked = state.postDetail?.savedPlaceIDs.contains(place.id)
            ?? state.map.bookmarkedPlaceIDs.contains(place.id)
        state.detail = detail
        state.map.selectedPlace = MapFeature.State.SelectedPlace(
            id: place.id,
            coordinate: place.coordinate
        )
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

    /// 게시글 장소를 지도 핀·장소 상세용 Place 로 바꾼다. 저장수는 응답에 없어 0 으로 둔다
    func place(_ detailPlace: PostDetailPlace) -> Place {
        Place(
            id: detailPlace.id,
            kakaoPlaceID: detailPlace.kakaoPlaceID,
            name: detailPlace.name,
            category: detailPlace.category,
            address: detailPlace.address,
            roadAddress: detailPlace.roadAddress,
            coordinate: detailPlace.coordinate,
            bookmarkCount: 0,
            thumbnailURLs: detailPlace.imageURLs
        )
    }
}
