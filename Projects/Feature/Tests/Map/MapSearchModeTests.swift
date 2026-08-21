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

    func test_북마크는_화면_안에서만_켜지고_꺼진다() async {
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.bookmarkTapped("s1")) {
            $0.bookmarkedPlaceIDs = ["s1"]
        }
        XCTAssertTrue(store.state.isBookmarked("s1"))

        await store.send(.bookmarkTapped("s1")) {
            $0.bookmarkedPlaceIDs = []
        }
        XCTAssertFalse(store.state.isBookmarked("s1"))
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
}
