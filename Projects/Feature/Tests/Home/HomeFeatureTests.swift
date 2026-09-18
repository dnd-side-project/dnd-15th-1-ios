import ComposableArchitecture
import Domain
@testable import Feature
import Foundation
import SharedDesignSystem
import XCTest

private struct BoomError: Error {}

private let profile = UserProfile(nickname: "나", iconID: 0, datePreference: nil)

private let connectedStatus = CoupleStatus.connected(
    me: CoupleMember(nickname: "나", iconID: 0),
    partner: CoupleMember(nickname: "짝", iconID: 1),
    daysTogether: 3
)

private let recommendationFeed = ContentFeed(
    page: ContentPage(
        items: [Content(id: "c1", title: "코스", thumbnailURLs: [], placeCount: 1)],
        hasNext: false
    ),
    popularTags: []
)

private let bannerCourse = DateCourseSummary(
    id: "42",
    title: "성수동 데이트",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    totalPlaceCount: 5
)

@MainActor
final class HomeFeatureTests: XCTestCase {
    func test_장소저장후_홈갱신_저장장소와_추천을_다시받는다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.placeClient.recentSavedPlaces = { _ in [.fixture(id: "1")] }
            $0.profileClient.member = { profile }
            $0.contentClient.contents = { _, _, _ in recommendationFeed }
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
            $0.placeClient.recentSavedPlaces = { _ in throw BoomError() }
            $0.profileClient.member = { profile }
            $0.contentClient.contents = { _, _, _ in throw BoomError() }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        // 재조회가 실패하면 loaded 액션이 오지 않아 기존 섹션이 그대로 남는다
        await store.send(.placesImported)

        XCTAssertEqual(store.state.savedPlaces.map(\.id), ["keep"])
        XCTAssertEqual(store.state.recommendations.map(\.id), ["keep"])
    }

    func test_당겨서새로고침_요약_저장장소_추천을_다시읽고_isRefreshing이_참이된다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coupleClient.current = { .notConnected }
            $0.placeClient.recentSavedPlaces = { _ in [.fixture(id: "1")] }
            $0.profileClient.member = { profile }
            $0.contentClient.contents = { _, _, _ in recommendationFeed }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.refreshRequested)
        await store.skipReceivedActions()

        XCTAssertTrue(store.state.isRefreshing)
        XCTAssertEqual(store.state.nickname, "나")
        XCTAssertEqual(store.state.savedPlaces.map(\.id), ["1"])
        XCTAssertEqual(store.state.recommendations.map(\.id), ["c1"])
    }

    func test_당겨서새로고침_저장장소실패시_토스트가_선다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coupleClient.current = { .notConnected }
            $0.placeClient.recentSavedPlaces = { _ in throw BoomError() }
            $0.profileClient.member = { profile }
            $0.contentClient.contents = { _, _, _ in recommendationFeed }
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
            $0.coupleClient.current = { .notConnected }
            $0.placeClient.recentSavedPlaces = { _ in throw BoomError() }
            $0.profileClient.member = { profile }
            $0.contentClient.contents = { _, _, _ in recommendationFeed }
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
            $0.coupleClient.current = { throw CoupleError.unauthorized }
            $0.placeClient.recentSavedPlaces = { _ in [.fixture(id: "1")] }
            $0.profileClient.member = { profile }
            $0.contentClient.contents = { _, _, _ in recommendationFeed }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.refreshRequested)
        await store.receive(.summaryLoadFailed(isSessionExpired: true))
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
        } withDependencies: {
            $0.analyticsClient.track = { _ in }
        }

        await store.send(.bannerTapped)
        await store.receive(.delegate(.showCourseResult(dateCourseID: bannerCourse.id, origin: .courseBuilt)))
    }

    func test_지난일정을_누르면_지난데이트_출처로_코스결과를_올린다() async {
        let schedule = DateCourseSummary(
            id: "77",
            title: "성수역 데이트",
            scheduledAt: Date(timeIntervalSince1970: 1_785_942_000),
            status: nil,
            totalPlaceCount: 5
        )
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

    func test_코스짜기_요청은_홈배너_진입_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.courseFlowRequested)
        await store.receive(.delegate(.courseFlowRequested))
        await store.finish()

        XCTAssertEqual(sent.value, [.courseCreateStarted(entryPoint: .homeBanner)])
    }

    func test_배너를_누르면_홈배너_코스보기_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = TestStore(
            initialState: HomeFeature.State(
                nickname: "나",
                partnerName: "짝",
                upcomingSchedule: bannerCourse
            )
        ) {
            HomeFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.bannerTapped)
        await store.receive(.delegate(.showCourseResult(dateCourseID: bannerCourse.id, origin: .courseBuilt)))
        await store.finish()

        XCTAssertEqual(sent.value, [.courseViewed(entryPoint: .homeBanner)])
    }
}

// 위 클래스가 type_body_length 한계에 가까워 요약 로딩은 따로 둔다
@MainActor
final class HomeFeatureSummaryTests: XCTestCase {
    func test_진입하면_커플과_회원을_한_묶음으로_읽는다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coupleClient.current = { connectedStatus }
            $0.profileClient.member = { profile }
            $0.courseClient.currentCourse = { nil }
            $0.courseClient.latestPastCourses = { _ in [] }
            $0.placeClient.recentSavedPlaces = { _ in [] }
            $0.contentClient.contents = { _, _, _ in recommendationFeed }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(.summaryLoaded(profile: profile, couple: connectedStatus))
        await store.receive(.currentCourseLoaded(nil))
        await store.skipReceivedActions()

        XCTAssertTrue(store.state.didLoadSummary)
        XCTAssertEqual(store.state.partnerName, "짝")
    }

    func test_연결됐으면_현재코스까지_받은_뒤_요약을_켠다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.courseClient.currentCourse = { bannerCourse }
            $0.courseClient.latestPastCourses = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.summaryLoaded(profile: profile, couple: connectedStatus)) {
            $0.nickname = "나"
            $0.partnerName = "짝"
        }
        XCTAssertFalse(store.state.didLoadSummary)

        await store.receive(\.currentCourseLoaded) {
            $0.upcomingSchedule = bannerCourse
            $0.didLoadSummary = true
        }
    }

    func test_미연결이면_현재코스를_부르지_않고_요약을_켠다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        }

        await store.send(.summaryLoaded(profile: profile, couple: .notConnected)) {
            $0.nickname = "나"
            $0.didLoadSummary = true
        }
    }

    func test_회원_조회가_실패하면_요약_실패다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coupleClient.current = { connectedStatus }
            $0.profileClient.member = { throw ProfileError.network }
        }

        await store.send(.reloadRequested)
        await store.receive(.summaryLoadFailed(isSessionExpired: false)) {
            $0.didLoadSummary = true
        }
    }

    func test_회원_조회가_인증만료면_로그인으로_보낸다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.coupleClient.current = { connectedStatus }
            $0.profileClient.member = { throw ProfileError.unauthorized }
        }

        await store.send(.reloadRequested)
        await store.receive(.summaryLoadFailed(isSessionExpired: true)) {
            $0.didLoadSummary = true
        }
        await store.receive(.delegate(.sessionExpired))
    }

    func test_현재코스가_실패하면_이전_배너를_두고_새로고침이면_토스트를_띄운다() async {
        var initial = HomeFeature.State(nickname: "나", partnerName: "짝", upcomingSchedule: bannerCourse)
        initial.isRefreshing = true
        let store = TestStore(initialState: initial) {
            HomeFeature()
        } withDependencies: {
            $0.courseClient.currentCourse = { throw CourseError.network }
            $0.courseClient.latestPastCourses = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.summaryLoaded(profile: profile, couple: connectedStatus))
        await store.receive(\.currentCourseLoadFailed) {
            $0.didLoadSummary = true
        }
        await store.receive(\.refreshFailed) {
            $0.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
        }

        XCTAssertEqual(store.state.upcomingSchedule, bannerCourse)
    }

    func test_처음_열때_현재코스가_실패하면_배너가_비고_토스트가_없다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.courseClient.currentCourse = { throw CourseError.network }
            $0.courseClient.latestPastCourses = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.summaryLoaded(profile: profile, couple: connectedStatus))
        await store.receive(\.currentCourseLoadFailed) {
            $0.didLoadSummary = true
        }
        await store.skipReceivedActions()

        XCTAssertNil(store.state.upcomingSchedule)
        XCTAssertNil(store.state.toast)
    }

    func test_현재코스가_인증만료여도_로그인으로_보내지_않는다() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: {
            $0.courseClient.currentCourse = { throw CourseError.unauthorized }
            // 지난 데이트는 끝나지 않게 둬 받은 액션 순서를 현재 코스 하나로 고정한다
            $0.courseClient.latestPastCourses = { _ in try await Task.never() }
        }

        await store.send(.summaryLoaded(profile: profile, couple: connectedStatus)) {
            $0.nickname = "나"
            $0.partnerName = "짝"
        }
        await store.receive(\.currentCourseLoadFailed) {
            $0.didLoadSummary = true
        }
        await store.skipInFlightEffects()
    }
}
