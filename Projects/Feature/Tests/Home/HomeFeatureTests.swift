import ComposableArchitecture
import Domain
import Feature
import Foundation
import XCTest

private struct BoomError: Error {}

@MainActor
final class HomeFeatureTests: XCTestCase {
    func test_장소저장후_홈갱신_저장장소와_추천을_다시받는다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeClient.recentSavedPlaces = { _ in [.fixture(id: "1")] }
            $0.profileClient.member = { UserProfile(nickname: "둘픽", iconID: 0, datePreference: nil) }
            $0.exploreClient.contents = { _, _, _ in
                ContentPage(
                    items: [Content(id: "c1", title: "코스", thumbnailURLs: [], placeCount: 1)],
                    hasNext: false,
                    popularTags: []
                )
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.placesImported)
        await store.receive(\.savedPlacesLoaded)
        await store.receive(\.recommendationsLoaded)

        XCTAssertEqual(store.state.savedPlaces.map(\.id), ["1"])
        XCTAssertEqual(store.state.recommendations.map(\.id), ["c1"])
    }

    func test_장소저장후_홈갱신_실패시_기존데이터_유지() async {
        var initial = HomeFeature.State()
        initial.savedPlaces = [.fixture(id: "keep")]
        initial.recommendations = [Content(id: "keep", title: "유지", thumbnailURLs: [], placeCount: 2)]

        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0.homeClient.recentSavedPlaces = { _ in throw BoomError() }
            $0.profileClient.member = { UserProfile(nickname: "둘픽", iconID: 0, datePreference: nil) }
            $0.exploreClient.contents = { _, _, _ in throw BoomError() }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // 재조회가 실패하면 loaded 액션이 오지 않아 기존 섹션이 그대로 남는다
        await store.send(.placesImported)

        XCTAssertEqual(store.state.savedPlaces.map(\.id), ["keep"])
        XCTAssertEqual(store.state.recommendations.map(\.id), ["keep"])
    }
}
