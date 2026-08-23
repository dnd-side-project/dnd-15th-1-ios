import ComposableArchitecture
import Domain
import Feature
import XCTest

final class CourseTimeMinimumTests: XCTestCase {

    func test_오늘을_고르면_시각_하한이_5분_올림이다() {
        let now = date(year: 2026, month: 8, day: 23, hour: 22, minute: 3)
        var state = CourseFeature.State(now: now)
        state.date = state.today

        XCTAssertEqual(state.timeWheelMinimum?.hour, 22)
        XCTAssertEqual(state.timeWheelMinimum?.minute, 5)
    }

    func test_오늘_정각이면_시각_하한이_그대로다() {
        let now = date(year: 2026, month: 8, day: 23, hour: 22, minute: 0)
        var state = CourseFeature.State(now: now)
        state.date = state.today

        XCTAssertEqual(state.timeWheelMinimum?.hour, 22)
        XCTAssertEqual(state.timeWheelMinimum?.minute, 0)
    }

    func test_23시58분이면_시각_하한이_23시55분이다() {
        let now = date(year: 2026, month: 8, day: 23, hour: 23, minute: 58)
        var state = CourseFeature.State(now: now)
        state.date = state.today

        XCTAssertEqual(state.timeWheelMinimum?.hour, 23)
        XCTAssertEqual(state.timeWheelMinimum?.minute, 55)
    }

    func test_다른_날을_고르면_시각_하한이_없다() {
        let now = date(year: 2026, month: 8, day: 23, hour: 22, minute: 3)
        var state = CourseFeature.State(now: now)
        state.date = DateComponents(year: 2026, month: 8, day: 24)

        XCTAssertNil(state.timeWheelMinimum)
    }

    func test_날짜를_안_골랐으면_오늘이라_시각_하한이_걸린다() {
        let now = date(year: 2026, month: 8, day: 23, hour: 22, minute: 3)
        let state = CourseFeature.State(now: now)

        XCTAssertNil(state.date)
        XCTAssertEqual(state.draftDate, state.today)
        XCTAssertEqual(state.timeWheelMinimum?.hour, 22)
        XCTAssertEqual(state.timeWheelMinimum?.minute, 5)
    }
}

@MainActor
final class CoursePastTimeGuardTests: XCTestCase {

    func test_오늘_지난_시각이면_다음이_에러를_내고_요청을_안_보낸다() async {
        let now = date(year: 2026, month: 8, day: 23, hour: 22, minute: 0)
        var initial = CourseFeature.State(now: now)
        initial.date = initial.today
        initial.time = DateComponents(hour: 13, minute: 0)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = now
            $0.courseClient.createCourse = { _, _, _ in
                XCTFail("지난 시각이면 코스를 만들지 않는다")
                return dummyCourse
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped) {
            $0.showsTimeError = true
        }
        XCTAssertFalse(store.state.isCreatingCourse)
    }

    func test_시각을_안_골랐고_기본값_오후한시가_지났으면_에러다() async {
        let now = date(year: 2026, month: 8, day: 23, hour: 22, minute: 0)
        var initial = CourseFeature.State(now: now)
        initial.date = initial.today
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = now
            $0.courseClient.createCourse = { _, _, _ in
                XCTFail("지난 기본 시각이면 코스를 만들지 않는다")
                return dummyCourse
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped) {
            $0.showsTimeError = true
        }
        XCTAssertNil(store.state.time)
        XCTAssertFalse(store.state.isCreatingCourse)
    }

    func test_오늘_아직_안_지난_시각이면_다음이_나간다() async {
        let now = date(year: 2026, month: 8, day: 23, hour: 10, minute: 0)
        var initial = CourseFeature.State(now: now)
        initial.date = initial.today
        initial.time = DateComponents(hour: 13, minute: 0)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = now
            $0.courseClient.createCourse = { _, _, time in
                XCTAssertEqual(time.hour, 13)
                XCTAssertEqual(time.minute, 0)
                return dummyCourse
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped)
        await store.receive(\.courseCreated)
        await store.receive(.delegate(.placePickRequested(dateCourseID: "1")))
    }

    func test_열_때는_미래였는데_누를_때는_지났으면_에러다() async {
        let opened = date(year: 2026, month: 8, day: 23, hour: 10, minute: 0)
        let tapped = date(year: 2026, month: 8, day: 23, hour: 14, minute: 0)
        var initial = CourseFeature.State(now: opened)
        initial.date = initial.today
        initial.time = DateComponents(hour: 13, minute: 0)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        } withDependencies: {
            $0.date.now = tapped
            $0.courseClient.createCourse = { _, _, _ in
                XCTFail("누를 때 지난 시각이면 코스를 만들지 않는다")
                return dummyCourse
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.nextTapped) {
            $0.showsTimeError = true
        }
        XCTAssertFalse(store.state.isCreatingCourse)
    }

    func test_시각_에러가_있는_채_날짜를_바꾸면_에러가_지워진다() async {
        let now = date(year: 2026, month: 8, day: 23, hour: 22, minute: 0)
        var initial = CourseFeature.State(now: now)
        initial.date = initial.today
        initial.time = DateComponents(hour: 13, minute: 0)
        initial.showsTimeError = true
        initial.activeWheel = .date
        initial.draftDate = DateComponents(year: 2026, month: 8, day: 24)
        let store = TestStore(initialState: initial) {
            CourseFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.wheelConfirmed) {
            $0.date = DateComponents(year: 2026, month: 8, day: 24)
            $0.activeWheel = nil
            $0.showsTimeError = false
        }
    }
}

private func date(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int
) -> Date {
    Calendar.current.date(
        from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    ) ?? Date.distantPast
}

private let dummyCourse = DateCourse(
    id: "1",
    title: "t",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .draft,
    version: 0,
    stops: [],
    legs: []
)
