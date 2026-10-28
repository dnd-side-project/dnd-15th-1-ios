import CoreKakaoMap
import Domain
@testable import Feature
import SharedDesignSystem
import SharedUtils
import ThirdParty
import XCTest

@MainActor
final class MapSearchModeTests: XCTestCase {
    func test_검색결과를_받으면_핀이_결과로_바뀐다() async {
        let results = [
            PlaceSearchResult.unsaved(.fixture(id: "s1", latitude: 37.5000, longitude: 127.0000)),
            PlaceSearchResult.unsaved(.fixture(id: "s2", latitude: 37.5100, longitude: 127.0100)),
        ]
        let store = TestStore(initialState: MapFeature.State()) {
            MapFeature()
        }

        await store.send(.searchResultsApplied(query: "음식점", results: results, isSavedOnly: false)) {
            $0.mode = .searchResult(query: "음식점", results: results, isSavedOnly: false)
            $0.camera.center = Coordinate(latitude: 37.5000, longitude: 127.0000)
        }

        XCTAssertEqual(store.state.markers.map(\.id), ["s1", "s2"])
        XCTAssertTrue(store.state.isSearching)
        XCTAssertEqual(store.state.searchQuery, "음식점")
    }

    func test_검색을_끄면_저장장소로_돌아온다() async {
        let results = [PlaceSearchResult.unsaved(.fixture(id: "s1", latitude: 37.5, longitude: 127.0))]
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", results: results, isSavedOnly: false)

        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.searchClearTapped) {
            $0.mode = .saved
        }

        XCTAssertFalse(store.state.isSearching)
        XCTAssertNil(store.state.searchQuery)
        XCTAssertTrue(store.state.markers.isEmpty)
    }

    func test_검색모드에서_뒤로가면_검색어와_함께_다시열기를_올린다() async {
        let results = [PlaceSearchResult.unsaved(.fixture(id: "s1", latitude: 37.5, longitude: 127.0))]
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", results: results, isSavedOnly: false)

        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.searchBackTapped)
        await store.receive(.delegate(.searchReopenRequested(query: "음식점")))
    }

    func test_저장장소모드에서_뒤로가기는_아무_일도_안_한다() async {
        let store = TestStore(initialState: MapFeature.State()) { MapFeature() }

        await store.send(.searchBackTapped)
    }

    func test_검색모드에서는_저장자_필터가_핀에_안_걸린다() async {
        let results = [
            PlaceSearchResult.unsaved(.fixture(id: "s1", latitude: 37.5, longitude: 127.0)),
            PlaceSearchResult.unsaved(.fixture(id: "s2", latitude: 37.51, longitude: 127.01)),
        ]
        var state = MapFeature.State()
        state.mode = .searchResult(query: "음식점", results: results, isSavedOnly: false)
        state.selectedOwnership = .mine
        state.selectedCategory = .cafe

        let store = TestStore(initialState: state) { MapFeature() }

        XCTAssertEqual(store.state.markers.count, 2)
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

    func test_검색_결과를_깔면_서버가_저장했다는_곳은_북마크에_더하고_아니라는_곳은_뺀다() async {
        let saved = PlaceSearchResult(
            place: .fixture(id: "s1", latitude: 37.5, longitude: 127.0),
            ownership: .partner,
            alias: nil
        )
        let unsaved = PlaceSearchResult.unsaved(.fixture(id: "s2", latitude: 37.51, longitude: 127.01))
        var state = MapFeature.State()
        state.bookmarkedPlaceIDs = ["s2", "other"]
        let store = TestStore(initialState: state) { MapFeature() }

        await store.send(.searchResultsApplied(query: "성수", results: [saved, unsaved], isSavedOnly: false)) {
            $0.mode = .searchResult(query: "성수", results: [saved, unsaved], isSavedOnly: false)
            $0.bookmarkedPlaceIDs = ["s1", "other"]
            $0.camera = .focusing(saved.place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
    }

    func test_토글_결과를_깔면_모두_북마크에_더하고_토글_상태를_남긴다() async {
        let results = [
            PlaceSearchResult(savedPlace: .candidateFixture(id: "a", latitude: 37.5, longitude: 127.0)),
        ]
        let store = TestStore(initialState: MapFeature.State()) { MapFeature() }

        await store.send(.searchResultsApplied(query: "성수", results: results, isSavedOnly: true)) {
            $0.mode = .searchResult(query: "성수", results: results, isSavedOnly: true)
            $0.bookmarkedPlaceIDs = ["a"]
            $0.camera = .focusing(results[0].place.coordinate, zoomLevel: MapCamera.multiPlaceZoom)
        }
        XCTAssertTrue(store.state.searchIsSavedOnly)
    }
}
