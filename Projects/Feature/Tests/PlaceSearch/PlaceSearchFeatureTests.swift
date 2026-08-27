import Domain
import Feature
import SharedDesignSystem
import ThirdParty
import XCTest

@MainActor
final class PlaceSearchFeatureTests: XCTestCase {
    func test_검색어를_넣으면_300ms_뒤에_검색이_돈다() async {
        let clock = TestClock()
        let places = [Place.fixture(id: "1", name: "장소명")]
        let store = TestStore(initialState: PlaceSearchFeature.State()) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in PlacePage(items: places, hasNext: false) }
            $0.mapRecentSearchClient.load = { [] }
        }

        await store.send(.binding(.set(\.query, "음식점"))) {
            $0.query = "음식점"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.results = places
            $0.loadState = .loaded
        }
    }

    func test_검색어를_지우면_결과가_비고_검색이_안_돈다() async {
        let clock = TestClock()
        var state = PlaceSearchFeature.State()
        state.query = "음식점"
        state.results = [Place.fixture(id: "1", name: "장소명")]
        state.loadState = .loaded

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in
                XCTFail("빈 검색어로 서버를 부르면 안 된다")
                return PlacePage(items: [], hasNext: false)
            }
        }

        await store.send(.binding(.set(\.query, ""))) {
            $0.query = ""
            $0.results = []
            $0.loadState = .idle
        }
        await clock.advance(by: .milliseconds(300))
    }

    func test_결과가_비면_빈_결과_상태다() async {
        let clock = TestClock()
        let store = TestStore(initialState: PlaceSearchFeature.State()) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in PlacePage(items: [], hasNext: false) }
            $0.mapRecentSearchClient.load = { [] }
        }

        await store.send(.binding(.set(\.query, "없는곳"))) {
            $0.query = "없는곳"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.loadState = .loaded
        }
        XCTAssertTrue(store.state.isEmptyResult)
    }

    func test_엔터를_누르면_최근에_넣고_결과를_올린다() async {
        let places = [Place.fixture(id: "1", name: "장소명")]
        var state = PlaceSearchFeature.State()
        state.query = "음식점"
        state.results = places
        state.loadState = .loaded

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { term in [term] }
        }

        await store.send(.submitted)
        await store.receive(\.recentSearchesUpdated) {
            $0.recentSearches = ["음식점"]
        }
        await store.receive(\.delegate.searchConfirmed)
    }

    func test_결과가_비면_엔터가_아무것도_안_한다() async {
        var state = PlaceSearchFeature.State()
        state.query = "없는곳"
        state.results = []
        state.loadState = .loaded

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { _ in
                XCTFail("빈 결과를 최근 검색어에 넣으면 안 된다")
                return []
            }
        }

        await store.send(.submitted)
    }

    func test_최근검색어_한건_지우기와_모두_지우기() async {
        var state = PlaceSearchFeature.State()
        state.recentSearches = ["음식점", "카페"]

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.remove = { _ in ["카페"] }
            $0.mapRecentSearchClient.clear = {}
        }

        await store.send(.recentSearchDeleted("음식점"))
        await store.receive(\.recentSearchesUpdated) {
            $0.recentSearches = ["카페"]
        }

        await store.send(.clearRecentTapped)
        await store.receive(\.recentSearchesUpdated) {
            $0.recentSearches = []
        }
    }

    func test_검색이_실패하면_실패_상태다() async {
        let clock = TestClock()
        let store = TestStore(initialState: PlaceSearchFeature.State()) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in throw PlaceError.network }
            $0.mapRecentSearchClient.load = { [] }
        }

        await store.send(.binding(.set(\.query, "음식점"))) {
            $0.query = "음식점"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.failure) {
            $0.loadState = .failed
        }
    }

    func test_세션이_만료되면_위로_올린다() async {
        let clock = TestClock()
        let store = TestStore(initialState: PlaceSearchFeature.State()) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in throw PlaceError.unauthorized }
            $0.mapRecentSearchClient.load = { [] }
        }

        await store.send(.binding(.set(\.query, "음식점"))) {
            $0.query = "음식점"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.failure) {
            $0.loadState = .failed
        }
        await store.receive(\.delegate.sessionExpired)
    }

    func test_최근검색어를_누르면_그_말로_검색한다() async {
        let clock = TestClock()
        let places = [Place.fixture(id: "1", name: "장소명")]
        var state = PlaceSearchFeature.State()
        state.recentSearches = ["음식점"]

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in PlacePage(items: places, hasNext: false) }
        }

        await store.send(.recentSearchTapped("음식점")) {
            $0.query = "음식점"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.results = places
            $0.loadState = .loaded
        }
    }

    func test_새_검색어를_치면_이전_요청이_끊긴다() async {
        let clock = TestClock()
        let firstPlaces = [Place.fixture(id: "1", name: "음식점A")]
        let secondPlaces = [Place.fixture(id: "2", name: "카페B")]
        let firstSearchStarted = LockIsolated(false)

        let store = TestStore(initialState: PlaceSearchFeature.State()) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { query, _ in
                if query == "음식점" {
                    firstSearchStarted.setValue(true)
                    try await clock.sleep(for: .milliseconds(100))
                    return PlacePage(items: firstPlaces, hasNext: false)
                }
                return PlacePage(items: secondPlaces, hasNext: false)
            }
            $0.mapRecentSearchClient.load = { [] }
        }

        await store.send(.binding(.set(\.query, "음식점"))) {
            $0.query = "음식점"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }

        var attempts = 0
        while !firstSearchStarted.value && attempts < 100 {
            attempts += 1
            await Task.yield()
        }
        XCTAssertTrue(firstSearchStarted.value, "첫 요청이 시작되어야 한다")

        await store.send(.binding(.set(\.query, "카페"))) {
            $0.query = "카페"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced)
        await store.receive(\.searchResponse.success) {
            $0.results = secondPlaces
            $0.loadState = .loaded
        }
    }
}

@MainActor
final class PlaceSearchFeaturePaginationTests: XCTestCase {
    func test_끝에_닿으면_다음_페이지를_붙인다() async {
        let first = Array(Place.mocks.prefix(3))
        let second = Array(Place.mocks.suffix(2))
        let store = TestStore(initialState: PlaceSearchFeature.State(query: "성수")) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.placeClient.searchPlaces = { _, page in
                page == 0
                    ? PlacePage(items: first, hasNext: true)
                    : PlacePage(items: second, hasNext: false)
            }
            $0.mapRecentSearchClient.load = { [] }
        }

        await store.send(.onAppear) {
            $0.loadState = .loading
        }
        await store.receive(\.recentSearchesUpdated)
        await store.receive(\.searchResponse.success) {
            $0.results = first
            $0.hasNext = true
            $0.loadState = .loaded
        }

        await store.send(.reachedEnd) {
            $0.isLoadingMore = true
        }
        await store.receive(\.moreResponse.success) {
            $0.results = first + second
            $0.page = 1
            $0.hasNext = false
            $0.isLoadingMore = false
        }
    }

    func test_다음이_없으면_더_부르지_않는다() async {
        var state = PlaceSearchFeature.State(query: "성수")
        state.hasNext = false
        state.loadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        }

        await store.send(.reachedEnd)
    }

    func test_새_검색은_페이지를_0으로_되돌린다() async {
        let clock = TestClock()
        var state = PlaceSearchFeature.State()
        state.page = 3
        state.hasNext = true
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, page in
                XCTAssertEqual(page, 0)
                return PlacePage(items: Place.mocks, hasNext: false)
            }
        }

        await store.send(.binding(.set(\.query, "성수"))) {
            $0.query = "성수"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.page = 0
            $0.hasNext = false
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.results = Place.mocks
            $0.loadState = .loaded
        }
    }
}

@MainActor
final class PlaceSearchSelectionTests: XCTestCase {
    func test_행을_누르면_그_장소를_올린다() async {
        let place = Place.fixture(id: "1", name: "장소명")
        var state = PlaceSearchFeature.State()
        state.query = "음식점"
        state.results = [place]
        state.loadState = .loaded

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { term in [term] }
        }

        await store.send(.rowTapped("1"))
        await store.receive(\.recentSearchesUpdated) {
            $0.recentSearches = ["음식점"]
        }
        await store.receive(\.delegate.placeSelected)
    }

    func test_목록에_없는_행은_안_올린다() async {
        var state = PlaceSearchFeature.State()
        state.results = [Place.fixture(id: "1", name: "장소명")]

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { _ in
                XCTFail("없는 행을 최근 검색어에 넣으면 안 된다")
                return []
            }
        }

        await store.send(.rowTapped("없는id"))
    }
}
