import ComposableArchitecture
import Domain
@testable import Feature
import XCTest

@MainActor
final class SearchFeatureTests: XCTestCase {
    func test_검색은_장소를_장소_창구의_첫_페이지로_부른다() async {
        let place = Place.fixture(id: "p1", name: "성수 카페")
        let requested = LockIsolated<[String]>([])
        var state = SearchFeature.State()
        state.query = "성수"
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.contentClient.searchContents = { _, _, _, _ in ContentPage(items: [], hasNext: false) }
            $0.placeClient.searchPlaces = { query, page in
                requested.withValue { $0.append("\(query)#\(page)") }
                return PlacePage(items: [place], hasNext: true)
            }
        }

        await store.send(.queryChangeDebounced) {
            $0.isSearching = true
        }
        await store.receive(\.searchResponse) {
            $0.contentsHasNext = false
            $0.contentsPage = 1
            $0.places = [place]
            $0.placesPage = 1
            $0.isSearching = false
            $0.isFirstSearch = false
        }

        XCTAssertEqual(requested.value, ["성수#0"])
    }

    func test_장소_탭_끝에서_다음_장을_장소_창구로_부른다() async {
        var state = SearchFeature.State()
        state.query = "성수"
        state.selectedTab = .place
        state.placesPage = 1
        let next = [Place.fixture(id: "p2")]
        let store = TestStore(initialState: state) {
            SearchFeature()
        } withDependencies: {
            $0.placeClient.searchPlaces = { _, page in
                XCTAssertEqual(page, 1)
                return PlacePage(items: next, hasNext: false)
            }
        }

        await store.send(.reachedEnd) {
            $0.isLoadingMore = true
        }
        await store.receive(\.morePlacesLoaded) {
            $0.places = next
            $0.placesHasNext = false
            $0.placesPage = 2
            $0.isLoadingMore = false
        }
    }
}
