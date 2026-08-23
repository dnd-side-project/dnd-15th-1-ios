import Domain
import Feature
import Foundation
import ThirdParty
import XCTest

@MainActor
final class MapFlowCourseWiringTests: XCTestCase {

    func test_날짜검증통과_장소선택_push() async {
        var course = CourseFeature.State()
        course.date = DateComponents(year: 2030, month: 8, day: 5)
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: course,
                path: [.course]
            )
        ) {
            MapFlowFeature()
        } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 0)
            $0.courseClient.createCourse = { _, _, _ in
                DateCourse(
                    id: "42",
                    title: "t",
                    scheduledAt: Date(timeIntervalSince1970: 0),
                    status: .draft,
                    version: 0,
                    stops: [],
                    legs: []
                )
            }
        }

        await store.send(.course(.nextTapped)) {
            $0.course?.isCreatingCourse = true
        }
        await store.receive(\.course.courseCreated) {
            $0.course?.isCreatingCourse = false
            $0.course?.dateCourseID = "42"
            $0.course?.version = 0
        }
        await store.receive(.course(.delegate(.placePickRequested(dateCourseID: "42")))) {
            $0.path = [.course, .coursePlacePick]
        }
    }

    func test_경로가_비면_코스State_nil() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.course = nil
        }
    }

    func test_장소선택에서_뒤로가면_날짜화면이_남는다() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course, .coursePlacePick]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.course(.backTapped))
        await store.receive(\.course.delegate.dismissed)
        await store.receive(\.pathChanged) {
            $0.path = [.course]
        }
        XCTAssertNotNil(store.state.course)
    }

    func test_날짜화면에서_뒤로가면_코스가_닫힌다() async {
        let store = TestStore(
            initialState: MapFlowFeature.State(
                course: CourseFeature.State(),
                path: [.course]
            )
        ) {
            MapFlowFeature()
        }

        await store.send(.course(.backTapped))
        await store.receive(\.course.delegate.dismissed)
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.course = nil
        }
    }
}

@MainActor
final class MapFlowCourseResultTests: XCTestCase {

    func test_저장이_끝나면_결과_화면이_열린다() async {
        let store = TestStore(initialState: courseInProgressState()) {
            MapFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.course(.delegate(.buildRequested(confirmedCourse)))) {
            $0.path = [.course, .coursePlacePick, .courseResult]
        }
        XCTAssertEqual(store.state.courseResult?.course, confirmedCourse)
        XCTAssertEqual(store.state.courseResult?.dateCourseID, confirmedCourse.id)
        XCTAssertEqual(store.state.courseResult?.partnerNickname, "상대")
    }

    func test_결과에서_뒤로가면_지도_루트로_돌아간다() async {
        let store = TestStore(initialState: courseResultState()) {
            MapFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.courseResult(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.course = nil
            $0.courseResult = nil
        }
    }

    func test_경로가_비면_코스_상태가_같이_지워진다() async {
        let store = TestStore(initialState: courseResultState()) {
            MapFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.course = nil
            $0.courseResult = nil
        }
    }
}

// MARK: - Fixture

private let confirmedCourse = DateCourse(
    id: "42",
    title: "t",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 0,
    stops: [],
    legs: []
)

private func courseInProgressState() -> MapFlowFeature.State {
    var course = CourseFeature.State()
    course.partnerNickname = "상대"
    return MapFlowFeature.State(
        course: course,
        path: [.course, .coursePlacePick]
    )
}

private func courseResultState() -> MapFlowFeature.State {
    var state = courseInProgressState()
    state.path = [.course, .coursePlacePick, .courseResult]
    state.courseResult = CourseResultFeature.State(
        course: confirmedCourse,
        dateCourseID: confirmedCourse.id,
        partnerNickname: state.course?.partnerNickname
    )
    return state
}
