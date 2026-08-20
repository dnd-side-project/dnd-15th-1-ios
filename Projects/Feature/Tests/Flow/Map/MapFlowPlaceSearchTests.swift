import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class MapFlowPlaceSearchTests: XCTestCase {
    func test_검색바를_누르면_검색화면이_열린다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.searchRequested))) {
            $0.placeSearch = PlaceSearchFeature.State()
            $0.path = [.search]
        }
    }

    func test_다시열기를_받으면_검색어가_채워진_검색화면이_열린다() async {
        let store = TestStore(initialState: MapFlowFeature.State()) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.map(.delegate(.searchReopenRequested(query: "음식점")))) {
            $0.placeSearch = PlaceSearchFeature.State(query: "음식점")
            $0.path = [.search]
        }
    }

    func test_뒤로가면_검색화면이_닫힌다() async {
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State()
        state.path = [.search]

        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchClearTapped)
    }

    func test_엔터하면_닫고_지도에_결과를_넘긴다() async {
        let places = [Place.fixture(id: "s1", latitude: 37.5, longitude: 127.0)]
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State()
        state.path = [.search]

        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.searchConfirmed(query: "음식점", places: places))))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(query: "음식점", places: places)
        }
    }

    func test_엔터로_닫혀도_최근검색어가_저장된다() async {
        let places = [Place.fixture(id: "s1", latitude: 37.5, longitude: 127.0)]
        var search = PlaceSearchFeature.State()
        search.query = "음식점"
        search.results = places
        search.loadState = .loaded

        var state = MapFlowFeature.State()
        state.placeSearch = search
        state.path = [.search]

        let callCount = LockIsolated(0)
        let store = TestStore(initialState: state) {
            MapFlowFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { term in
                callCount.withValue { $0 += 1 }
                return [term]
            }
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.submitted))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(query: "음식점", places: places)
        }
        XCTAssertEqual(callCount.value, 1)
    }

    func test_검색결과에서_뒤로가면_저장장소로_빠져나온다() async {
        let places = [Place.fixture(id: "s1", latitude: 37.5, longitude: 127.0)]
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State()
        state.path = [.search]

        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.searchConfirmed(query: "음식점", places: places))))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchResultsApplied) {
            $0.map.mode = .searchResult(query: "음식점", places: places)
        }

        await store.send(.map(.searchBackTapped))
        await store.receive(\.map.delegate.searchReopenRequested) {
            $0.placeSearch = PlaceSearchFeature.State(query: "음식점")
            $0.path = [.search]
        }

        await store.send(.placeSearch(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.placeSearch = nil
        }
        await store.receive(\.map.searchClearTapped) {
            $0.map.mode = .saved
        }
    }

    func test_검색결과_행을_누르면_상세로_가고_검색이_정리된다() async {
        var state = MapFlowFeature.State()
        state.placeSearch = PlaceSearchFeature.State()
        state.path = [.search]

        let store = TestStore(initialState: state) {
            MapFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.placeSearch(.delegate(.placeSelected("p1"))))
        await store.receive(\.pathChanged) {
            $0.path = [.placeDetail("p1")]
            $0.placeSearch = nil
        }
    }
}
