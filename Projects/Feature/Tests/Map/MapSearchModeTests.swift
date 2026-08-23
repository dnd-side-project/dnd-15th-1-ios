import Domain
import Feature
import SharedDesignSystem
import ThirdParty
import XCTest

@MainActor
final class MapSearchModeTests: XCTestCase {
    func test_검색결과를_받으면_핀이_결과로_바뀐다() async {
        let places = [
            Place.fixture(id: "s1", latitude: 37.5000, longitude: 127.0000),
            Place.fixture(id: "s2", latitude: 37.5100, longitude: 127.0100),
        ]
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.searchResultsApplied(query: "음식점", places: places)) {
            $0.mode = .searchResult(query: "음식점", places: places)
            $0.camera.center = Coordinate(latitude: 37.5000, longitude: 127.0000)
        }

        XCTAssertEqual(store.state.markers.map(\.id), ["s1", "s2"])
        XCTAssertTrue(store.state.isSearching)
        XCTAssertEqual(store.state.searchQuery, "음식점")
    }

    func test_검색을_끄면_저장장소로_돌아온다() async {
        let places = [Place.fixture(id: "s1", latitude: 37.5, longitude: 127.0)]
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", places: places)

        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.searchClearTapped) {
            $0.mode = .saved
        }

        XCTAssertFalse(store.state.isSearching)
        XCTAssertNil(store.state.searchQuery)
        XCTAssertTrue(store.state.markers.isEmpty)
    }

    func test_검색모드에서_뒤로가면_검색어와_함께_다시열기를_올린다() async {
        let places = [Place.fixture(id: "s1", latitude: 37.5, longitude: 127.0)]
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", places: places)

        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.searchBackTapped)
        await store.receive(.delegate(.searchReopenRequested(query: "음식점")))
    }

    func test_저장장소모드에서_뒤로가기는_아무_일도_안_한다() async {
        let store = TestStore(initialState: MapFeature.State()) { MapFeature() }

        await store.send(.searchBackTapped)
    }

    func test_검색모드에서는_저장자_필터가_핀에_안_걸린다() async {
        let places = [
            Place.fixture(id: "s1", latitude: 37.5, longitude: 127.0),
            Place.fixture(id: "s2", latitude: 37.51, longitude: 127.01),
        ]
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", places: places)
        state.selectedOwnership = .mine
        state.selectedCategory = .cafe

        let store = TestStore(initialState: state) { MapFeature() }

        XCTAssertEqual(store.state.markers.count, 2)
    }

    func test_검색_행을_저장하면_savePlace를_부르고_서버id를_남긴다() async {
        let place = searchPlace()
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", places: [place])

        let saved = SavedPlace.mocks[0]
        let kakaoIDArg = LockIsolated<String?>(nil)
        let queryArg = LockIsolated<String?>(nil)
        let aliasArg = LockIsolated<String?>(nil)
        let memoArg = LockIsolated<String?>(nil)
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savePlace = { kakaoID, query, alias, memo in
                kakaoIDArg.setValue(kakaoID)
                queryArg.setValue(query)
                aliasArg.setValue(alias)
                memoArg.setValue(memo)
                return saved
            }
        }

        await store.send(.bookmarkTapped("s1")) {
            $0.bookmarkedPlaceIDs = ["s1"]
        }
        XCTAssertTrue(store.state.isBookmarked("s1"))

        await store.receive(.bookmarkSaved(id: "s1", saved: saved)) {
            $0.savedServerIDs = ["s1": saved.place.id]
            $0.places = [saved]
        }
        XCTAssertEqual(kakaoIDArg.value, "kakao-s1")
        XCTAssertEqual(queryArg.value, "검색 장소")
        XCTAssertNil(aliasArg.value)
        XCTAssertNil(memoArg.value)
    }

    func test_북마크된_검색_행을_다시_누르면_서버id로_지운다() async {
        let place = searchPlace()
        let saved = SavedPlace.mocks[0]
        let serverID = saved.place.id
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", places: [place])
        state.bookmarkedPlaceIDs = ["s1"]
        state.savedServerIDs = ["s1": serverID]
        state.places = [saved]

        let removedID = LockIsolated<String?>(nil)
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.removePlace = { placeID in
                removedID.setValue(placeID)
            }
        }

        await store.send(.bookmarkTapped("s1")) {
            $0.bookmarkedPlaceIDs = []
        }
        await store.receive(.bookmarkRemoved(id: "s1")) {
            $0.places = []
        }

        XCTAssertFalse(store.state.isBookmarked("s1"))
        XCTAssertEqual(removedID.value, serverID)
        XCTAssertFalse(store.state.places.contains { $0.id == serverID })
    }

    func test_저장이_실패하면_북마크_표시를_되돌린다() async {
        let place = searchPlace()
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", places: [place])

        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savePlace = { _, _, _, _ in throw PlaceError.network }
        }

        await store.send(.bookmarkTapped("s1")) {
            $0.bookmarkedPlaceIDs = ["s1"]
        }
        await store.receive(.bookmarkFailed(id: "s1", wasBookmarked: false)) {
            $0.bookmarkedPlaceIDs = []
        }
        XCTAssertFalse(store.state.isBookmarked("s1"))
        XCTAssertTrue(store.state.places.isEmpty)
    }

    func test_카카오id가_없으면_저장하지_않는다() async {
        let place = Place.fixture(id: "s1", latitude: 37.5, longitude: 127.0)
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", places: [place])

        let saveCalled = LockIsolated(false)
        let store = TestStore(initialState: state) {
            MapFeature()
        } withDependencies: {
            $0.placeClient.savePlace = { _, _, _, _ in
                saveCalled.setValue(true)
                return SavedPlace.mocks[0]
            }
        }

        await store.send(.bookmarkTapped("s1"))
        XCTAssertTrue(store.state.bookmarkedPlaceIDs.isEmpty)
        XCTAssertFalse(saveCalled.value)
    }

    func test_저장장소를_불러오면_북마크가_채워진다() async {
        let saved: [SavedPlace] = [
            .fixture(id: "1", latitude: 37.3128, longitude: 126.9040),
        ]
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.savedPlacesResponse(.success(saved))) {
            $0.places = saved
            $0.loadState = .loaded
            $0.bookmarkedPlaceIDs = ["1"]
            $0.camera = .focusing(saved[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }

    private func searchPlace() -> Place {
        Place(
            id: "s1",
            kakaoPlaceID: "kakao-s1",
            name: "검색 장소",
            category: .cafe,
            address: "경기도 안산시 상록구 건건동 1",
            roadAddress: "경기도 안산시 상록구 건건로 1",
            coordinate: Coordinate(latitude: 37.5, longitude: 127.0),
            bookmarkCount: 0,
            thumbnailURLs: []
        )
    }
}
