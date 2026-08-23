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
                    scheduledDate: Date(timeIntervalSince1970: 0),
                    scheduledTime: nil,
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
        } withDependencies: {
            $0.courseClient.currentCourse = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.courseResult(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.course = nil
            $0.courseResult = nil
        }
        await store.skipReceivedActions()
    }

    func test_예정_코스_버튼은_결과_화면을_연다() async {
        var map = MapFeature.State()
        map.currentCourse = mapFlowCurrentCourse
        map.partnerNickname = "상대"
        let store = TestStore(initialState: MapFlowFeature.State(map: map)) {
            MapFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.map(.courseButtonTapped))
        await store.receive(\.map.delegate.courseResultRequested) {
            $0.path = [.courseResult]
        }
        XCTAssertEqual(store.state.courseResult?.dateCourseID, mapFlowCurrentCourse.id)
        XCTAssertNil(store.state.courseResult?.course)
        XCTAssertEqual(store.state.courseResult?.partnerNickname, "상대")
        XCTAssertEqual(store.state.courseResult?.origin, .courseBuilt)
    }

    func test_결과에서_뒤로가면_예정_코스를_다시_받는다() async {
        let courseCalls = LockIsolated(0)
        let placeCalls = LockIsolated(0)
        let store = TestStore(initialState: courseResultState()) {
            MapFlowFeature()
        } withDependencies: {
            $0.courseClient.currentCourse = {
                courseCalls.withValue { $0 += 1 }
                return mapFlowCurrentCourse
            }
            $0.placeClient.savedPlaces = {
                placeCalls.withValue { $0 += 1 }
                return []
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.courseResult(.delegate(.dismissed)))
        await store.receive(\.pathChanged) {
            $0.path = []
            $0.course = nil
            $0.courseResult = nil
        }
        await store.receive(\.map.currentCourseRequested)
        await store.receive(\.map.currentCourseResponse) {
            $0.map.currentCourse = mapFlowCurrentCourse
        }
        XCTAssertEqual(courseCalls.value, 1)
        XCTAssertEqual(placeCalls.value, 0)
    }

    func test_경로가_비면_코스_상태가_같이_지워진다() async {
        let store = TestStore(initialState: courseResultState()) {
            MapFlowFeature()
        } withDependencies: {
            $0.courseClient.currentCourse = { nil }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.course = nil
            $0.courseResult = nil
        }
        await store.receive(\.map.currentCourseRequested)
        await store.skipReceivedActions()
    }
}

// MARK: - Fixture

private let mapFlowCurrentCourse = DateCourseSummary(
    id: "42",
    title: "성수동 데이트",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 1,
    totalPlaceCount: 5
)

private let confirmedCourse = DateCourse(
    id: "42",
    title: "t",
    scheduledDate: Date(timeIntervalSince1970: 0),
    scheduledTime: nil,
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

@MainActor
final class MapFlowCourseEditWiringTests: XCTestCase {

    func test_수정을_누르면_경로에_수정_화면이_쌓인다() async {
        let store = flowStore(courseResult: .init(course: threeStopCourse, dateCourseID: "1001"))
        store.exhaustivity = .off

        await store.send(.courseResult(.delegate(.editRequested(threeStopCourse))))

        XCTAssertEqual(store.state.path.last, .courseEdit)
        XCTAssertEqual(store.state.courseEdit?.dateCourseID, "1001")
    }

    func test_충돌하면_수정_화면을_빼고_결과를_다시_읽는다() async {
        let store = flowStore(
            courseResult: .init(course: threeStopCourse, dateCourseID: "1001"),
            courseEdit: .init(dateCourseID: "1001"),
            path: [.courseResult, .courseEdit]
        )
        store.exhaustivity = .off

        await store.send(.courseEdit(.delegate(.conflicted)))
        await store.receive(\.courseResult.conflictReloadRequested)

        XCTAssertFalse(store.state.path.contains(.courseEdit))
        XCTAssertNil(store.state.courseEdit)
    }

    func test_저장하면_수정_화면을_빼고_결과_코스를_바꾼다() async {
        let saved = twoStopCourse
        let store = flowStore(
            courseResult: .init(course: threeStopCourse, dateCourseID: "1001"),
            courseEdit: .init(dateCourseID: "1001"),
            path: [.courseResult, .courseEdit]
        )
        store.exhaustivity = .off

        await store.send(.courseEdit(.delegate(.saved(saved))))
        await store.receive(\.courseResult.courseResponse)

        XCTAssertFalse(store.state.path.contains(.courseEdit))
        XCTAssertEqual(store.state.courseResult?.course, saved)
    }

    func test_장소_추가는_고르기_모드로_화면을_쌓는다() async {
        let store = flowStore(
            courseEdit: .init(dateCourseID: "1001"),
            path: [.courseResult, .courseEdit]
        )
        store.exhaustivity = .off

        await store.send(.courseEdit(.delegate(.placeAddRequested(excluding: ["101"]))))

        XCTAssertEqual(store.state.path.last, .coursePlaceAdd)
        XCTAssertEqual(store.state.coursePlaceAdd?.mode, .pick(excluding: ["101"]))
        XCTAssertNil(store.state.course)
    }

    func test_고른_장소는_수정_화면으로_돌아간다() async {
        let picked = [candidate102]
        let store = flowStore(
            courseEdit: .init(dateCourseID: "1001"),
            coursePlaceAdd: .init(mode: .pick(excluding: ["101"])),
            path: [.courseResult, .courseEdit, .coursePlaceAdd]
        )
        store.exhaustivity = .off

        await store.send(.coursePlaceAdd(.delegate(.placesPicked(picked))))
        await store.receive(\.pathChanged)
        await store.receive(\.courseEdit.placesAdded)

        XCTAssertFalse(store.state.path.contains(.coursePlaceAdd))
        XCTAssertEqual(store.state.path.last, .courseEdit)
    }

    func test_장소_추가_뒤_경로는_만들기_고르기를_남긴다() async {
        var course = CourseFeature.State()
        course.partnerNickname = "상대"
        let store = flowStore(
            course: course,
            courseResult: .init(course: threeStopCourse, dateCourseID: "1001"),
            courseEdit: .init(dateCourseID: "1001"),
            path: [.course, .coursePlacePick, .courseResult, .courseEdit]
        )
        store.exhaustivity = .off

        await store.send(.courseEdit(.delegate(.placeAddRequested(excluding: ["p0"]))))
        await store.send(.coursePlaceAdd(.delegate(.placesPicked([candidate102]))))
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

@MainActor
private func flowStore(
    course: CourseFeature.State? = nil,
    courseResult: CourseResultFeature.State? = nil,
    courseEdit: CourseEditFeature.State? = nil,
    coursePlaceAdd: CourseFeature.State? = nil,
    path: [MapFlowFeature.Route] = []
) -> TestStoreOf<MapFlowFeature> {
    TestStore(
        initialState: MapFlowFeature.State(
            course: course,
            courseResult: courseResult,
            courseEdit: courseEdit,
            coursePlaceAdd: coursePlaceAdd,
            path: path
        )
    ) {
        MapFlowFeature()
    } withDependencies: {
        $0.courseClient.course = { _ in threeStopCourse }
    }
}

private let threeStopCourse = makeCourse(
    stopCount: 3,
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
        Domain.CourseLeg(walkingMinutes: 80, distanceMeters: 5300),
    ]
)

private let twoStopCourse = makeCourse(
    stopCount: 2,
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
    ]
)

private let candidate102 = CoursePlaceCandidate.fixture(id: "102")

private func makeCourse(
    stopCount: Int,
    legs: [Domain.CourseLeg?]
) -> DateCourse {
    DateCourse(
        id: "1001",
        title: "26.08.05 데이트",
        scheduledDate: Date(timeIntervalSince1970: 0),
        scheduledTime: nil,
        status: .confirmed,
        version: 1,
        stops: (0..<stopCount).map { index in
            Domain.CourseStop(
                place: .fixture(
                    id: "p\(index)",
                    latitude: 37.31 + Double(index) * 0.01,
                    longitude: 126.90 + Double(index) * 0.01
                )
            )
        },
        legs: legs
    )
}
