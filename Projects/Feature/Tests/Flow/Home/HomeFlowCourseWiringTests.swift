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

@MainActor
final class HomeFlowCourseEditWiringTests: XCTestCase {

    func test_수정을_누르면_경로에_수정_화면이_쌓인다() async {
        let store = TestStore(initialState: builtCourseResultState()) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.courseResult(.delegate(.editRequested(wiringCourse))))

        XCTAssertEqual(store.state.path.last, .courseEdit)
        XCTAssertEqual(store.state.courseEdit?.dateCourseID, wiringCourse.id)
    }

    func test_저장하면_수정_화면을_빼고_결과_코스를_바꾼다() async {
        let saved = DateCourse(
            id: wiringCourse.id,
            title: "saved",
            scheduledDate: wiringCourse.scheduledDate,
            scheduledTime: wiringCourse.scheduledTime,
            status: wiringCourse.status,
            version: 1,
            stops: wiringCourse.stops,
            legs: wiringCourse.legs
        )
        let store = TestStore(initialState: editingCourseResultState()) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.courseEdit(.delegate(.saved(saved))))
        await store.receive(\.courseResult.courseResponse)

        XCTAssertFalse(store.state.path.contains(.courseEdit))
        XCTAssertEqual(store.state.courseResult?.course, saved)
    }

    func test_충돌하면_수정_화면을_빼고_결과를_다시_읽는다() async {
        let store = TestStore(initialState: editingCourseResultState()) {
            HomeFlowFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in wiringCourse }
        }
        store.exhaustivity = .off

        await store.send(.courseEdit(.delegate(.conflicted)))
        await store.receive(\.courseResult.conflictReloadRequested)

        XCTAssertFalse(store.state.path.contains(.courseEdit))
        XCTAssertNil(store.state.courseEdit)
    }

    func test_장소_추가는_고르기_모드로_화면을_쌓인다() async {
        let store = TestStore(initialState: editingCourseResultState()) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.courseEdit(.delegate(.placeAddRequested(excluding: ["101"]))))

        XCTAssertEqual(store.state.path.last, .coursePlaceAdd)
        XCTAssertEqual(store.state.coursePlaceAdd?.mode, .pick(excluding: ["101"]))
        XCTAssertNotNil(store.state.course)
    }

    func test_고른_장소는_수정_화면으로_돌아간다() async {
        let picked = [CoursePlaceCandidate.fixture(id: "102")]
        var state = editingCourseResultState()
        state.coursePlaceAdd = CourseFeature.State(mode: .pick(excluding: ["101"]))
        state.path.append(.coursePlaceAdd)
        let store = TestStore(initialState: state) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.coursePlaceAdd(.delegate(.placesPicked(picked))))
        await store.receive(\.pathChanged)
        await store.receive(\.courseEdit.placesAdded)

        XCTAssertFalse(store.state.path.contains(.coursePlaceAdd))
        XCTAssertEqual(store.state.path.last, .courseEdit)
    }

    func test_장소_추가_뒤_경로는_만들기_고르기를_남긴다() async {
        let store = TestStore(initialState: editingCourseResultState()) {
            HomeFlowFeature()
        }
        store.exhaustivity = .off

        await store.send(.courseEdit(.delegate(.placeAddRequested(excluding: ["p0"]))))
        await store.send(.coursePlaceAdd(.delegate(.placesPicked([CoursePlaceCandidate.fixture(id: "102")]))))
        await store.receive(\.pathChanged)
        await store.receive(\.courseEdit.placesAdded)

        XCTAssertEqual(
            store.state.path,
            [.course, .coursePlacePick, .courseResult, .courseEdit]
        )
        XCTAssertNotNil(store.state.course)
        XCTAssertNil(store.state.coursePlaceAdd)
    }
}

private func editingCourseResultState() -> HomeFlowFeature.State {
    var state = builtCourseResultState()
    state.courseEdit = CourseEditFeature.State(dateCourseID: wiringCourse.id)
    state.path.append(.courseEdit)
    return state
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
    scheduledDate: Date(timeIntervalSince1970: 0),
    scheduledTime: nil,
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
