import Domain
import Feature
import SharedDesignSystem
import ThirdParty
import XCTest

@MainActor
final class MapFlowFeatureTests: XCTestCase {
    func test_핀을_탭하면_경로가_안_쌓이고_흐름이_상세를_연다() async {
        let saved = SavedPlace.fixture(id: "7", latitude: 37.3, longitude: 126.9)
        var map = MapFeature.State()
        map.places = [saved]
        // 실제로는 저장 목록을 받을 때 둘을 같이 채운다. 상세가 북마크 여부를 이 집합에서 읽는다
        map.bookmarkedPlaceIDs = [saved.id]
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }

        await store.send(.map(.markerTapped("7")))
        await store.receive(\.map.delegate.placeDetailRequested) {
            $0.detail = PlaceDetailFeature.State(savedPlace: saved)
            $0.map.selectedPlace = MapFeature.State.SelectedPlace(
                id: saved.id,
                coordinate: saved.place.coordinate
            )
        }
        XCTAssertEqual(store.state.path, [])
    }

    func test_행을_탭해도_경로가_안_쌓이고_흐름이_상세를_연다() async {
        let saved = SavedPlace.fixture(id: "7", latitude: 37.3, longitude: 126.9)
        var map = MapFeature.State()
        map.places = [saved]
        // 실제로는 저장 목록을 받을 때 둘을 같이 채운다. 상세가 북마크 여부를 이 집합에서 읽는다
        map.bookmarkedPlaceIDs = [saved.id]
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }

        await store.send(.map(.rowTapped("7")))
        await store.receive(\.map.delegate.placeDetailRequested) {
            $0.detail = PlaceDetailFeature.State(savedPlace: saved)
            $0.map.selectedPlace = MapFeature.State.SelectedPlace(
                id: saved.id,
                coordinate: saved.place.coordinate
            )
        }
        XCTAssertEqual(store.state.path, [])
    }

    func test_목록에_없는_id_면_상세가_안_선다() async {
        let saved = SavedPlace.fixture(id: "7", latitude: 37.3, longitude: 126.9)
        var map = MapFeature.State()
        map.places = [saved]
        // 실제로는 저장 목록을 받을 때 둘을 같이 채운다. 상세가 북마크 여부를 이 집합에서 읽는다
        map.bookmarkedPlaceIDs = [saved.id]
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }

        await store.send(.map(.rowTapped("없는id")))
        await store.receive(\.map.delegate.placeDetailRequested)
        XCTAssertNil(store.state.detail)
        XCTAssertNil(store.state.map.selectedPlace)
    }

    func test_검색_결과에서_행을_누르면_상세가_선다() async {
        let place = Place.fixture(id: "s1", name: "검색 장소")
        var map = MapFeature.State()
        map.mode = .searchResult(query: "카페", places: [place])
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }

        await store.send(.map(.rowTapped("s1")))
        await store.receive(\.map.delegate.placeDetailRequested) {
            $0.detail = PlaceDetailFeature.State(place: place)
            $0.map.selectedPlace = MapFeature.State.SelectedPlace(
                id: place.id,
                coordinate: place.coordinate
            )
        }
        XCTAssertNil(store.state.detail?.alias)
        XCTAssertEqual(store.state.path, [])
    }

    func test_검색바와_코스_버튼이_각자_경로를_쌓는다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }

        await store.send(.map(.searchBarTapped))
        await store.receive(\.map.delegate.searchRequested) {
            $0.placeSearch = PlaceSearchFeature.State()
            $0.path = [.search]
        }

        await store.send(.map(.courseButtonTapped))
        await store.receive(\.map.delegate.courseRequested) {
            $0.path = [.search, .course]
            $0.course = CourseFeature.State()
        }
    }

    func test_뷰가_경로를_비우면_지도로_돌아온다() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(path: [.search, .course])
        ) {
            MapFlowFeature()
        }

        await store.send(.pathChanged([.search])) {
            $0.path = [.search]
        }
        await store.send(.pathChanged([])) {
            $0.path = []
        }
    }

    func test_수정을_요청하면_별칭시트가_서고_경로는_안_바뀐다() async {
        let saved = SavedPlace.fixture(id: "7", latitude: 37.3, longitude: 126.9)
        var map = MapFeature.State()
        map.places = [saved]
        // 실제로는 저장 목록을 받을 때 둘을 같이 채운다. 상세가 북마크 여부를 이 집합에서 읽는다
        map.bookmarkedPlaceIDs = [saved.id]
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }

        await store.send(.map(.delegate(.aliasRequested("7")))) {
            $0.alias = PlaceAliasFeature.State(savedPlace: saved)
        }
        XCTAssertEqual(store.state.path, [])
    }

    func test_삭제는_화면_이동이_아니라_경로를_안_바꾼다() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(map: MapFeature.State())
        ) {
            MapFlowFeature()
        }

        // PlaceClient 에 계약이 생기면 데이터 갱신으로 받는다. path 를 쓰지 않는다
        await store.send(.map(.delegate(.deleteRequested("7"))))

        XCTAssertEqual(store.state.path, [])
    }

    func test_세션_만료는_경로를_안_쌓고_위로_올린다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }

        // 전역 에러라 RootFlow 까지 올라가야 로그인으로 되돌아간다
        await store.send(.map(.delegate(.sessionExpired)))
        await store.receive(\.delegate.sessionExpired)

        XCTAssertEqual(store.state.path, [])
    }

    func test_상세를_닫으면_자식이_사라지고_선택핀이_빠진다() async {
        let saved = SavedPlace.fixture(id: "7", latitude: 37.3, longitude: 126.9)
        var map = MapFeature.State()
        map.places = [saved]
        map.selectedPlace = MapFeature.State.SelectedPlace(
            id: saved.id,
            coordinate: saved.place.coordinate
        )
        var state = MapFlowFeature.State(map: map)
        state.detail = PlaceDetailFeature.State(savedPlace: saved)
        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }

        await store.send(.detail(.presented(.delegate(.closed)))) {
            $0.detail = nil
            $0.map.selectedPlace = nil
        }
    }

    func test_북마크_신호는_삼킨다() async {
        let saved = SavedPlace.fixture(id: "7", latitude: 37.3, longitude: 126.9)
        var state = MapFlowFeature.State()
        state.detail = PlaceDetailFeature.State(savedPlace: saved)
        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }

        await store.send(.detail(.presented(.delegate(.bookmarkToggled("7", false)))))
    }

    func test_별칭을_저장하면_목록을_지도에_넘긴다() async {
        let saved = SavedPlace.fixture(id: "7", latitude: 37.3, longitude: 126.9)
        var map = MapFeature.State()
        map.places = [saved]
        var state = MapFlowFeature.State(map: map)
        state.alias = PlaceAliasFeature.State(savedPlace: saved)
        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }

        await store.send(.alias(.presented(.delegate(.saved("7", "우리 첫 카페"))))) {
            $0.alias = nil
        }
        await store.receive(\.map.aliasSaved) {
            let old = $0.map.places[0]
            $0.map.places[0] = SavedPlace(
                place: old.place,
                ownership: old.ownership,
                alias: "우리 첫 카페",
                memo: old.memo,
                savedAt: old.savedAt
            )
            $0.map.toast = ToastState(message: "별칭을 저장했어요")
        }
    }
}

@MainActor
final class MapFlowSelectedPinTests: XCTestCase {
    private let savedPlaces: [SavedPlace] = [
        .fixture(id: "1", latitude: 37.3128, longitude: 126.9040),
        .fixture(id: "2", latitude: 37.3141, longitude: 126.9068),
    ]

    private func loadedStore() -> TestStoreOf<MapFlowFeature> {
        var map = MapFeature.State()
        map.places = savedPlaces
        map.loadState = .loaded
        return TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }
    }

    func test_상세가_없으면_마커개수가_기존과_같다() async {
        let store = loadedStore()
        XCTAssertEqual(store.state.map.markers.count, store.state.map.filteredPlaces.count)
        XCTAssertEqual(store.state.map.markers.map(\.kind), [.category(.cafe), .category(.cafe)])
    }

    func test_상세가_열리면_선택핀이_맨뒤에_붙는다() async {
        let store = loadedStore()
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.map(.markerTapped("1")))
        await store.receive(\.map.delegate.placeDetailRequested)

        XCTAssertEqual(store.state.map.markers.count, 3)
        XCTAssertEqual(store.state.map.markers.last?.kind, .selected)
        XCTAssertEqual(
            store.state.map.markers.last?.coordinate,
            savedPlaces[0].place.coordinate
        )
    }

    func test_상세가_열려도_기존_카테고리핀은_그대로다() async {
        let store = loadedStore()
        store.exhaustivity = .off(showSkippedAssertions: false)
        let before = store.state.map.markers

        await store.send(.map(.markerTapped("1")))
        await store.receive(\.map.delegate.placeDetailRequested)

        XCTAssertEqual(Array(store.state.map.markers.dropLast()), before)
    }

    func test_상세를_닫으면_선택핀이_빠진다() async {
        let store = loadedStore()
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.map(.markerTapped("1")))
        await store.receive(\.map.delegate.placeDetailRequested)
        XCTAssertEqual(store.state.map.markers.count, 3)

        await store.send(.detail(.presented(.delegate(.closed))))
        XCTAssertEqual(store.state.map.markers.count, 2)
        XCTAssertFalse(store.state.map.markers.contains { $0.kind == .selected })
    }
}
