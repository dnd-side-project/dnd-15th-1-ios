import ComposableArchitecture
import Domain
import Feature
import Foundation
import SharedDesignSystem
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

    func test_당겨서새로고침_홈요약_저장장소_추천을_다시읽고_isRefreshing이_참이된다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeClient.home = {
                HomeSummary(
                    connected: false,
                    myNickname: "둘픽",
                    partnerNickname: nil,
                    currentDateCourse: nil
                )
            }
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

        await store.send(.refreshRequested)
        await store.skipReceivedActions()

        XCTAssertTrue(store.state.isRefreshing)
        XCTAssertEqual(store.state.nickname, "둘픽")
        XCTAssertEqual(store.state.savedPlaces.map(\.id), ["1"])
        XCTAssertEqual(store.state.recommendations.map(\.id), ["c1"])
    }

    func test_당겨서새로고침_저장장소실패시_토스트가_선다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeClient.home = {
                HomeSummary(
                    connected: false,
                    myNickname: "둘픽",
                    partnerNickname: nil,
                    currentDateCourse: nil
                )
            }
            $0.homeClient.recentSavedPlaces = { _ in throw BoomError() }
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

        await store.send(.refreshRequested)
        await store.receive(\.refreshFailed)

        XCTAssertEqual(store.state.toast, ToastState(message: "잠시 뒤 다시 시도해주세요"))
    }

    func test_자동진입_저장장소실패시_토스트가_안선다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeClient.home = {
                HomeSummary(
                    connected: false,
                    myNickname: "둘픽",
                    partnerNickname: nil,
                    currentDateCourse: nil
                )
            }
            $0.homeClient.recentSavedPlaces = { _ in throw BoomError() }
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

        await store.send(.onAppear)
        await store.skipReceivedActions()

        XCTAssertNil(store.state.toast)
        XCTAssertFalse(store.state.isRefreshing)
    }

    func test_당겨서새로고침_세션만료는_토스트없이_sessionExpired만_올린다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.homeClient.home = { throw HomeError.unauthorized }
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

        await store.send(.refreshRequested)
        await store.receive(\.homeLoadFailed)
        await store.receive(\.delegate.sessionExpired)

        XCTAssertNil(store.state.toast)
    }

    func test_배너를_누르면_코스결과를_올린다() async {
        let store = TestStore(
            initialState: HomeFeature.State(
                nickname: "나",
                partnerName: "짝",
                upcomingSchedule: bannerCourse
            )
        ) {
            HomeFeature()
        }

        await store.send(.bannerTapped)
        await store.receive(.delegate(.showCourseResult(dateCourseID: bannerCourse.id, origin: .courseBuilt)))
    }

    func test_지난일정을_누르면_지난데이트_출처로_코스결과를_올린다() async {
        let schedule = DateSchedule(id: "77", title: "성수역 데이트", placeCount: 5, date: "26.08.06")
        let store = TestStore(
            initialState: HomeFeature.State(
                nickname: "나",
                partnerName: "짝",
                pastSchedules: [schedule]
            )
        ) {
            HomeFeature()
        }

        await store.send(.pastScheduleTapped("77"))
        await store.receive(.delegate(.showCourseResult(dateCourseID: "77", origin: .pastDate)))
    }

    func test_예정코스가_없으면_배너탭은_아무일도_안한다() async {
        let store = TestStore(
            initialState: HomeFeature.State(nickname: "나", partnerName: "짝")
        ) {
            HomeFeature()
        }

        await store.send(.bannerTapped)
    }
}

private let bannerCourse = DateCourseSummary(
    id: "42",
    title: "성수동 데이트",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 1,
    totalPlaceCount: 5
)
