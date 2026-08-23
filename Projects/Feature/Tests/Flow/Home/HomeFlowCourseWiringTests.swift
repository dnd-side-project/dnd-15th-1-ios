import Domain
import Feature
import Foundation
import ThirdParty
import XCTest

@MainActor
final class HomeFlowCourseWiringTests: XCTestCase {

    func test_코스를_짜고_완성하면_결과_화면이_열린다() async {
        let store = TestStore(initialState: courseInProgressState()) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.course(.delegate(.buildRequested(wiringCourse)))) {
            $0.path = [.course, .coursePlacePick, .courseResult]
        }
        XCTAssertEqual(store.state.courseResult?.course, wiringCourse)
        XCTAssertEqual(store.state.courseResult?.dateCourseID, wiringCourse.id)
        XCTAssertEqual(store.state.courseResult?.partnerNickname, "짝")
        XCTAssertEqual(store.state.courseResult?.origin, .courseBuilt)
    }

    func test_코스_결과에서_뒤로가면_홈_루트로_돌아간다() async {
        let store = TestStore(initialState: builtCourseResultState()) {
            HomeFlowFeature()
        } withDependencies: {
            $0.homeClient.home = { wiringHomeSummary }
            $0.homeClient.pastDates = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.courseResult(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.course = nil
            $0.courseResult = nil
        }
        await store.receive(\.home.reloadRequested)
        await store.skipReceivedActions()
    }

    func test_지난데이트_행을_누르면_결과_화면이_열린다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(nickname: "나", partnerName: "짝"),
                pastDateCourses: PastDateCoursesFeature.State(),
                path: [.pastDateCourses]
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pastDateCourses(.courseTapped("77")))
        await store.receive(\.pastDateCourses.delegate.courseSelected) {
            $0.path = [.pastDateCourses, .courseResult]
        }
        XCTAssertEqual(store.state.courseResult?.dateCourseID, "77")
        XCTAssertNil(store.state.courseResult?.course)
        XCTAssertEqual(store.state.courseResult?.origin, .pastDate)
    }

    func test_지난데이트로_연_결과에서_뒤로가면_목록으로_돌아간다() async {
        let store = TestStore(initialState: pastDateCourseResultState()) {
            HomeFlowFeature()
        } withDependencies: {
            $0.homeClient.home = { wiringHomeSummary }
            $0.homeClient.pastDates = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.courseResult(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = [.pastDateCourses]
            $0.courseResult = nil
        }
        await store.skipReceivedActions()
    }

    func test_지난데이트에서_만든_코스_결과를_닫으면_목록으로_돌아간다() async {
        let store = TestStore(initialState: pastDateBuiltCourseResultState()) {
            HomeFlowFeature()
        } withDependencies: {
            $0.homeClient.home = { wiringHomeSummary }
            $0.homeClient.pastDates = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.courseResult(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = [.pastDateCourses]
            $0.course = nil
            $0.courseResult = nil
        }
        await store.skipReceivedActions()
        XCTAssertNotNil(store.state.pastDateCourses)
    }

    func test_홈_배너를_누르면_예정_코스_결과_화면이_열린다() async {
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(
                    nickname: "나",
                    partnerName: "짝",
                    upcomingSchedule: bannerCourse
                )
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.home(.bannerTapped))
        await store.receive(\.home.delegate.showCourseResult) {
            $0.path = [.courseResult]
        }
        XCTAssertEqual(store.state.courseResult?.dateCourseID, bannerCourse.id)
        XCTAssertNil(store.state.courseResult?.course)
        XCTAssertEqual(store.state.courseResult?.partnerNickname, "짝")
        XCTAssertEqual(store.state.courseResult?.origin, .courseBuilt)
    }

    func test_홈_지난일정을_누르면_지난데이트_결과_화면이_열린다() async {
        let schedule = DateSchedule(id: "77", title: "성수역 데이트", placeCount: 5, date: "26.08.06")
        let store = TestStore(
            initialState: HomeFlowFeature.State(
                home: HomeFeature.State(
                    nickname: "나",
                    partnerName: "짝",
                    pastSchedules: [schedule]
                )
            )
        ) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.home(.pastScheduleTapped("77")))
        await store.receive(\.home.delegate.showCourseResult) {
            $0.path = [.courseResult]
        }
        XCTAssertEqual(store.state.courseResult?.dateCourseID, "77")
        XCTAssertNil(store.state.courseResult?.course)
        XCTAssertEqual(store.state.courseResult?.origin, .pastDate)
    }

    func test_홈_배너로_연_결과에서_뒤로가면_홈_루트로_돌아간다() async {
        let store = TestStore(initialState: homeBannerCourseResultState()) {
            HomeFlowFeature()
        } withDependencies: {
            $0.homeClient.home = { wiringHomeSummary }
            $0.homeClient.pastDates = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.courseResult(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.courseResult = nil
        }
        await store.skipReceivedActions()
    }

    func test_경로가_비면_결과_상태가_같이_지워진다() async {
        let store = TestStore(initialState: builtCourseResultState()) {
            HomeFlowFeature()
        } withDependencies: {
            $0.homeClient.home = { wiringHomeSummary }
            $0.homeClient.pastDates = { _ in [] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.course = nil
            $0.courseResult = nil
        }
        await store.receive(\.home.reloadRequested)
        await store.skipReceivedActions()
    }
}

// MARK: - Fixture

private let bannerCourse = DateCourseSummary(
    id: "42",
    title: "성수동 데이트",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 1,
    totalPlaceCount: 5
)

private let wiringHomeSummary = HomeSummary(
    connected: true,
    myNickname: "나",
    partnerNickname: "짝",
    currentDateCourse: bannerCourse
)

private let wiringCourse = DateCourse(
    id: "42",
    title: "t",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 0,
    stops: [],
    legs: []
)

private func courseInProgressState() -> HomeFlowFeature.State {
    var course = CourseFeature.State()
    course.partnerNickname = "짝"
    return HomeFlowFeature.State(
        home: HomeFeature.State(nickname: "나", partnerName: "짝"),
        course: course,
        path: [.course, .coursePlacePick]
    )
}

private func builtCourseResultState() -> HomeFlowFeature.State {
    var state = courseInProgressState()
    state.path = [.course, .coursePlacePick, .courseResult]
    state.courseResult = CourseResultFeature.State(
        course: wiringCourse,
        dateCourseID: wiringCourse.id,
        partnerNickname: state.course?.partnerNickname
    )
    return state
}

private func pastDateBuiltCourseResultState() -> HomeFlowFeature.State {
    var course = CourseFeature.State()
    course.partnerNickname = "짝"
    return HomeFlowFeature.State(
        home: HomeFeature.State(nickname: "나", partnerName: "짝"),
        pastDateCourses: PastDateCoursesFeature.State(),
        course: course,
        courseResult: CourseResultFeature.State(
            course: wiringCourse,
            dateCourseID: wiringCourse.id,
            partnerNickname: "짝"
        ),
        path: [.pastDateCourses, .course, .coursePlacePick, .courseResult]
    )
}

private func homeBannerCourseResultState() -> HomeFlowFeature.State {
    HomeFlowFeature.State(
        home: HomeFeature.State(nickname: "나", partnerName: "짝"),
        courseResult: CourseResultFeature.State(
            course: nil,
            dateCourseID: bannerCourse.id,
            partnerNickname: "짝",
            origin: .courseBuilt
        ),
        path: [.courseResult]
    )
}

private func pastDateCourseResultState() -> HomeFlowFeature.State {
    HomeFlowFeature.State(
        home: HomeFeature.State(nickname: "나", partnerName: "짝"),
        pastDateCourses: PastDateCoursesFeature.State(),
        courseResult: CourseResultFeature.State(
            course: nil,
            dateCourseID: "77",
            partnerNickname: "짝",
            origin: .pastDate
        ),
        path: [.pastDateCourses, .courseResult]
    )
}
