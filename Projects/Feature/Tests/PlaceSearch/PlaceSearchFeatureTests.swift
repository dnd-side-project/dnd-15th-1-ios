import Domain
import Feature
import SharedDesignSystem
import ThirdParty
import XCTest

@MainActor
final class PlaceSearchFeatureTests: XCTestCase {
    func test_검색어를_넣으면_300ms_뒤에_검색이_돈다() async {
        let clock = TestClock()
        let results = [PlaceSearchResult.unsaved(.fixture(id: "1", name: "장소명"))]
        let store = TestStore(initialState: PlaceSearchFeature.State()) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in Page(items: results, hasNext: false) }
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
            $0.results = results
            $0.loadState = .loaded
        }
    }

    func test_검색어를_지우면_결과가_비고_검색이_안_돈다() async {
        let clock = TestClock()
        var state = PlaceSearchFeature.State()
        state.query = "음식점"
        state.results = [PlaceSearchResult.unsaved(.fixture(id: "1", name: "장소명"))]
        state.loadState = .loaded

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in
                XCTFail("빈 검색어로 서버를 부르면 안 된다")
                return Page(items: [], hasNext: false)
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
            $0.placeClient.searchPlaces = { _, _ in Page(items: [], hasNext: false) }
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
        let results = [PlaceSearchResult.unsaved(.fixture(id: "1", name: "장소명"))]
        var state = PlaceSearchFeature.State()
        state.query = "음식점"
        state.results = results
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
        await store.receive(.delegate(.searchConfirmed(query: "음식점", results: results, isSavedOnly: false)))
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
        let results = [PlaceSearchResult.unsaved(.fixture(id: "1", name: "장소명"))]
        var state = PlaceSearchFeature.State()
        state.recentSearches = ["음식점"]

        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in Page(items: results, hasNext: false) }
        }

        await store.send(.recentSearchTapped("음식점")) {
            $0.query = "음식점"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.results = results
            $0.loadState = .loaded
        }
    }

    func test_새_검색어를_치면_이전_요청이_끊긴다() async {
        let clock = TestClock()
        let firstResults = [PlaceSearchResult.unsaved(.fixture(id: "1", name: "음식점A"))]
        let secondResults = [PlaceSearchResult.unsaved(.fixture(id: "2", name: "카페B"))]
        let firstSearchStarted = LockIsolated(false)

        let store = TestStore(initialState: PlaceSearchFeature.State()) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { query, _ in
                if query == "음식점" {
                    firstSearchStarted.setValue(true)
                    try await clock.sleep(for: .milliseconds(100))
                    return Page(items: firstResults, hasNext: false)
                }
                return Page(items: secondResults, hasNext: false)
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
            $0.results = secondResults
            $0.loadState = .loaded
        }
    }

    func test_검색어를_들고_들어오면_바로_검색한다() async {
        let results = [PlaceSearchResult.unsaved(.fixture(id: "1", name: "장소명"))]
        let gate = AsyncStream.makeStream(of: Void.self)
        let store = TestStore(initialState: PlaceSearchFeature.State(query: "성수")) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.placeClient.searchPlaces = { _, page in
                XCTAssertEqual(page, 0)
                // 최근 검색어가 먼저 도착하도록 검색 응답을 붙잡아 둔다
                for await _ in gate.stream { break }
                return Page(items: results, hasNext: true)
            }
            $0.mapRecentSearchClient.load = { ["카페"] }
        }

        await store.send(.onAppear) {
            $0.loadState = .loading
        }
        await store.receive(\.recentSearchesUpdated) {
            $0.recentSearches = ["카페"]
        }

        gate.continuation.finish()
        await store.receive(\.searchResponse.success) {
            $0.results = results
            $0.hasNext = true
            $0.loadState = .loaded
        }
    }
}

@MainActor
final class PlaceSearchFeaturePaginationTests: XCTestCase {
    func test_끝에_닿으면_다음_페이지를_붙인다() async {
        let first = Place.mocks.prefix(3).map(PlaceSearchResult.unsaved)
        let second = Place.mocks.suffix(2).map(PlaceSearchResult.unsaved)
        var state = PlaceSearchFeature.State(query: "성수")
        state.results = first
        state.hasNext = true
        state.loadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.placeClient.searchPlaces = { _, page in
                XCTAssertEqual(page, 1)
                return Page(items: second, hasNext: false)
            }
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
        let results = Place.mocks.map(PlaceSearchResult.unsaved)
        var state = PlaceSearchFeature.State()
        state.page = 3
        state.hasNext = true
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, page in
                XCTAssertEqual(page, 0)
                return Page(items: results, hasNext: false)
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
            $0.results = results
            $0.loadState = .loaded
        }
    }
}

@MainActor
final class PlaceSearchSelectionTests: XCTestCase {
    func test_행을_누르면_그_장소를_올린다() async {
        let result = PlaceSearchResult.unsaved(.fixture(id: "1", name: "장소명"))
        var state = PlaceSearchFeature.State()
        state.query = "음식점"
        state.results = [result]
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
        await store.receive(.delegate(.placeSelected(result, query: "음식점")))
    }

    func test_목록에_없는_행은_안_올린다() async {
        var state = PlaceSearchFeature.State()
        state.results = [PlaceSearchResult.unsaved(.fixture(id: "1", name: "장소명"))]

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

/// 커플 저장 장소 검색이 주는 한 건. 카카오 번호가 없고 별칭이 있다
private enum SavedOnlyFixture {
    static let saved = SavedPlace(
        place: SavedPlace.candidateFixture(id: "a").place,
        ownership: .partner,
        alias: "우리 카페",
        memo: nil,
        savedAt: nil
    )
    static let result = PlaceSearchResult(savedPlace: saved)
}

@MainActor
final class PlaceSearchSavedOnlyTests: XCTestCase {
    func test_커플이_없으면_토글을_켠_채로_만들어도_꺼져_있다() {
        XCTAssertFalse(PlaceSearchFeature.State(isSavedOnly: true, isCoupleConnected: false).isSavedOnly)
        XCTAssertTrue(PlaceSearchFeature.State(isSavedOnly: true, isCoupleConnected: true).isSavedOnly)
    }

    func test_토글을_켜면_기다리지_않고_코스_장소_검색으로_다시_찾는다() async {
        var state = PlaceSearchFeature.State(query: "성수", isCoupleConnected: true)
        state.results = [PlaceSearchResult.unsaved(.fixture(id: "1"))]
        state.loadState = .loaded
        let requested = LockIsolated<[String]>([])
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.courseClient.searchCoursePlaces = { query, page in
                requested.withValue { $0.append("\(query ?? "nil")#\(page)") }
                return Page(items: [SavedOnlyFixture.saved], hasNext: true)
            }
        }

        // 시계를 넘기지 않는다. 기다렸다면 응답이 오지 않는다
        await store.send(.binding(.set(\.isSavedOnly, true))) {
            $0.isSavedOnly = true
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.results = [SavedOnlyFixture.result]
            $0.hasNext = true
            $0.loadState = .loaded
        }
        XCTAssertEqual(requested.value, ["성수#0"])
    }

    func test_토글을_끄면_지도_검색으로_다시_찾는다() async {
        var state = PlaceSearchFeature.State(query: "성수", isSavedOnly: true, isCoupleConnected: true)
        state.results = [SavedOnlyFixture.result]
        state.loadState = .loaded
        let unsaved = [PlaceSearchResult.unsaved(.fixture(id: "1"))]
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.placeClient.searchPlaces = { query, page in
                XCTAssertEqual(query, "성수")
                XCTAssertEqual(page, 0)
                return Page(items: unsaved, hasNext: false)
            }
        }

        await store.send(.binding(.set(\.isSavedOnly, false))) {
            $0.isSavedOnly = false
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.results = unsaved
            $0.loadState = .loaded
        }
    }

    func test_토글을_바꾸면_돌던_지도_검색_요청을_끊는다() async {
        let clock = TestClock()
        let mapSearchStarted = LockIsolated(false)
        let store = TestStore(initialState: PlaceSearchFeature.State(isCoupleConnected: true)) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.placeClient.searchPlaces = { _, _ in
                mapSearchStarted.setValue(true)
                try await clock.sleep(for: .seconds(1))
                return Page(items: [PlaceSearchResult.unsaved(.fixture(id: "1"))], hasNext: false)
            }
            $0.courseClient.searchCoursePlaces = { _, _ in
                Page(items: [SavedOnlyFixture.saved], hasNext: false)
            }
        }

        await store.send(.binding(.set(\.query, "성수"))) {
            $0.query = "성수"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }
        var attempts = 0
        while !mapSearchStarted.value && attempts < 100 {
            attempts += 1
            await Task.yield()
        }
        XCTAssertTrue(mapSearchStarted.value, "지도 검색 요청이 먼저 시작되어야 한다")

        await store.send(.binding(.set(\.isSavedOnly, true))) {
            $0.isSavedOnly = true
        }
        await store.receive(\.searchResponse.success) {
            $0.results = [SavedOnlyFixture.result]
            $0.loadState = .loaded
        }
        // 끊기지 않았다면 여기서 지도 검색 응답이 한 번 더 온다
        await clock.advance(by: .seconds(1))
    }

    func test_토글을_켜도_검색어가_비면_최근_검색어를_보이고_서버를_부르지_않는다() async {
        let store = TestStore(initialState: PlaceSearchFeature.State(isCoupleConnected: true)) {
            PlaceSearchFeature()
        }

        await store.send(.binding(.set(\.isSavedOnly, true))) {
            $0.isSavedOnly = true
        }
        XCTAssertTrue(store.state.showsRecent)
    }

    func test_토글이_켜진_채로_검색어를_바꾸면_토글을_유지하고_코스_장소_검색을_부른다() async {
        let clock = TestClock()
        let store = TestStore(
            initialState: PlaceSearchFeature.State(isSavedOnly: true, isCoupleConnected: true)
        ) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.courseClient.searchCoursePlaces = { query, _ in
                XCTAssertEqual(query, "카페")
                return Page(items: [SavedOnlyFixture.saved], hasNext: false)
            }
        }

        await store.send(.binding(.set(\.query, "카페"))) {
            $0.query = "카페"
        }
        await clock.advance(by: .milliseconds(300))
        await store.receive(\.queryChangeDebounced) {
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.success) {
            $0.results = [SavedOnlyFixture.result]
            $0.loadState = .loaded
        }
        XCTAssertTrue(store.state.isSavedOnly)
    }

    func test_토글_결과_검색이_실패하면_실패_상태다() async {
        var state = PlaceSearchFeature.State(query: "성수", isCoupleConnected: true)
        state.results = [PlaceSearchResult.unsaved(.fixture(id: "1"))]
        state.loadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            // 커플 연결이 끊기면 서버가 404 를 준다
            $0.courseClient.searchCoursePlaces = { _, _ in throw CourseError.notFound }
        }

        await store.send(.binding(.set(\.isSavedOnly, true))) {
            $0.isSavedOnly = true
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.failure) {
            $0.results = []
            $0.loadState = .failed
        }
    }

    func test_토글_결과_검색에서_세션이_만료되면_위로_올린다() async {
        var state = PlaceSearchFeature.State(query: "성수", isCoupleConnected: true)
        state.loadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.courseClient.searchCoursePlaces = { _, _ in throw CourseError.unauthorized }
        }

        await store.send(.binding(.set(\.isSavedOnly, true))) {
            $0.isSavedOnly = true
            $0.loadState = .loading
        }
        await store.receive(\.searchResponse.failure) {
            $0.loadState = .failed
        }
        await store.receive(\.delegate.sessionExpired)
    }
}

@MainActor
final class PlaceSearchSavedOnlySelectionTests: XCTestCase {
    func test_토글_결과_행을_누르면_저장_목록처럼_올린다() async {
        var state = PlaceSearchFeature.State(query: "성수", isSavedOnly: true, isCoupleConnected: true)
        state.results = [SavedOnlyFixture.result]
        state.loadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { term in [term] }
        }

        await store.send(.rowTapped(SavedOnlyFixture.result.id))
        await store.receive(\.recentSearchesUpdated) {
            $0.recentSearches = ["성수"]
        }
        await store.receive(.delegate(.savedPlaceSelected(SavedOnlyFixture.saved)))
    }

    func test_토글을_끈_결과는_저장한_곳도_카카오_상세로_올린다() async {
        let savedOnMap = PlaceSearchResult(place: .fixture(id: "1"), ownership: .mine, alias: nil)
        var state = PlaceSearchFeature.State(query: "성수", isCoupleConnected: true)
        state.results = [savedOnMap]
        state.loadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { term in [term] }
        }

        await store.send(.rowTapped("1"))
        await store.receive(\.recentSearchesUpdated) {
            $0.recentSearches = ["성수"]
        }
        await store.receive(.delegate(.placeSelected(savedOnMap, query: "성수")))
    }

    func test_토글_결과로_엔터하면_토글_상태를_같이_올린다() async {
        var state = PlaceSearchFeature.State(query: "성수", isSavedOnly: true, isCoupleConnected: true)
        state.results = [SavedOnlyFixture.result]
        state.loadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.mapRecentSearchClient.add = { term in [term] }
        }

        await store.send(.submitted)
        await store.receive(\.recentSearchesUpdated) {
            $0.recentSearches = ["성수"]
        }
        await store.receive(
            .delegate(.searchConfirmed(query: "성수", results: [SavedOnlyFixture.result], isSavedOnly: true))
        )
    }

    func test_토글을_바꾼_뒤_로딩_중에_엔터하면_아무것도_안_올린다() async {
        var state = PlaceSearchFeature.State(query: "성수", isSavedOnly: true, isCoupleConnected: true)
        state.results = [SavedOnlyFixture.result]
        state.loadState = .loaded
        let unsaved = [PlaceSearchResult.unsaved(.fixture(id: "1"))]
        let gate = AsyncStream.makeStream(of: Void.self)
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.placeClient.searchPlaces = { _, _ in
                // 엔터가 로딩 중에 오도록 응답을 붙잡아 둔다
                for await _ in gate.stream { break }
                return Page(items: unsaved, hasNext: false)
            }
            $0.mapRecentSearchClient.add = { term in [term] }
        }

        await store.send(.binding(.set(\.isSavedOnly, false))) {
            $0.isSavedOnly = false
            $0.loadState = .loading
        }
        // 상태에 남은 토글 결과를 꺼진 토글로 올리면 카카오 번호가 없어 상세가 빈다
        await store.send(.submitted)

        gate.continuation.finish()
        await store.receive(\.searchResponse.success) {
            $0.results = unsaved
            $0.loadState = .loaded
        }
    }

    func test_토글_결과에서_끝에_닿으면_코스_장소_검색의_다음_페이지를_붙인다() async {
        let next = SavedPlace.candidateFixture(id: "b")
        var state = PlaceSearchFeature.State(query: "성수", isSavedOnly: true, isCoupleConnected: true)
        state.results = [SavedOnlyFixture.result]
        state.hasNext = true
        state.loadState = .loaded
        let store = TestStore(initialState: state) {
            PlaceSearchFeature()
        } withDependencies: {
            $0.courseClient.searchCoursePlaces = { query, page in
                XCTAssertEqual(query, "성수")
                XCTAssertEqual(page, 1)
                return Page(items: [next], hasNext: false)
            }
        }

        await store.send(.reachedEnd) {
            $0.isLoadingMore = true
        }
        await store.receive(\.moreResponse.success) {
            $0.results = [SavedOnlyFixture.result, PlaceSearchResult(savedPlace: next)]
            $0.page = 1
            $0.hasNext = false
            $0.isLoadingMore = false
        }
    }
}
