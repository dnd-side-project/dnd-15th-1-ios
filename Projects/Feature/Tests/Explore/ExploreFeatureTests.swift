import ComposableArchitecture
import Domain
@testable import Feature
import XCTest

@MainActor
final class ExploreFeatureTests: XCTestCase {
    func test_첫_피드의_인기_태그로_필터칩을_만든다() async {
        let page = ContentPage(
            items: [Content(id: "c1", title: "코스", thumbnailURLs: [], placeCount: 1)],
            hasNext: true
        )
        let store = TestStore(initialState: ExploreFeature.State()) {
            ExploreFeature()
        } withDependencies: {
            $0.contentClient.contents = { _, _, _ in ContentFeed(page: page, popularTags: ["성수", "강남"]) }
        }

        await store.send(.onAppear) {
            $0.isLoadingContents = true
        }
        await store.receive(\.contentsResponse) {
            $0.isLoadingContents = false
            $0.contents = page.items
            $0.filters = ["인기", "#성수", "#강남"]
            $0.page = 1
        }
    }

    func test_태그를_고르면_검색으로_받고_필터칩은_그대로다() async {
        var state = ExploreFeature.State()
        state.filters = ["인기", "#성수"]
        let store = TestStore(initialState: state) {
            ExploreFeature()
        } withDependencies: {
            $0.contentClient.searchContents = { query, _, _, _ in
                XCTAssertEqual(query, "성수")
                return ContentPage(items: [], hasNext: false)
            }
        }

        await store.send(.filterTapped("#성수")) {
            $0.selectedFilter = "#성수"
            $0.isLoadingContents = true
        }
        await store.receive(\.contentsResponse) {
            $0.isLoadingContents = false
            $0.hasNext = false
            $0.page = 1
        }
    }
}
