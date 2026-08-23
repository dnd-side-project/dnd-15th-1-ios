import ComposableArchitecture
import Domain
@testable import Feature
import Foundation
import SharedDesignSystem
import XCTest

@MainActor
final class CourseEditFeatureTests: XCTestCase {

    func test_진입하면_최신을_읽고_폼과_스냅샷을_채운다() async {
        let store = TestStore(initialState: CourseEditFeature.State(dateCourseID: "1001")) {
            CourseEditFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in threeStopCourse }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.courseResponse)

        XCTAssertEqual(store.state.loadState, .loaded)
        XCTAssertEqual(store.state.title, threeStopCourse.title)
        XCTAssertEqual(store.state.version, threeStopCourse.version)
        XCTAssertEqual(store.state.places.count, 3)
        XCTAssertFalse(store.state.hasChanges)
    }

    func test_진입에_실패하면_failed가_된다() async {
        let store = TestStore(initialState: CourseEditFeature.State(dateCourseID: "1001")) {
            CourseEditFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in throw CourseError.network }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.courseResponse)

        XCTAssertEqual(store.state.loadState, .failed)
    }

    func test_순서를_바꾸면_배열이_따라_바뀐다() async {
        let store = await loadedStore()
        await store.send(.placeMoved(from: 2, to: 0))
        XCTAssertEqual(store.state.places.map(\.id), ["p2", "p0", "p1"])
    }

    func test_삭제하면_목록에서_빠지고_토스트가_뜬다() async {
        let store = await loadedStore()
        await store.send(.placeDeleteTapped(id: "p1"))
        XCTAssertEqual(store.state.places.map(\.id), ["p0", "p2"])
        XCTAssertEqual(store.state.toast?.actionTitle, "실행취소")
        XCTAssertEqual(store.state.toast?.message, "'장소명' 삭제")
    }

    func test_실행취소하면_원래_자리로_돌아온다() async {
        let store = await loadedStore()
        let original = store.state.places.map(\.id)
        await store.send(.placeDeleteTapped(id: "p1"))
        await store.send(.undoTapped)
        XCTAssertEqual(store.state.places.map(\.id), original)
    }

    func test_토스트가_닫히면_되돌릴_수_없다() async {
        let store = await loadedStore()
        await store.send(.placeDeleteTapped(id: "p1"))
        await store.send(.toastDismissed)
        let ids = store.state.places.map(\.id)
        await store.send(.undoTapped)
        XCTAssertEqual(store.state.places.map(\.id), ids)
    }

    func test_연달아_지우면_직전_하나만_되돌린다() async {
        let store = await loadedStore()
        await store.send(.placeDeleteTapped(id: "p0"))
        await store.send(.placeDeleteTapped(id: "p1"))
        await store.send(.undoTapped)
        XCTAssertEqual(store.state.places.map(\.id), ["p1", "p2"])
    }

    func test_장소가_0개면_저장할_수_없다() async {
        let store = await loadedStore()
        await store.send(.placeDeleteTapped(id: "p0"))
        await store.send(.placeDeleteTapped(id: "p1"))
        await store.send(.placeDeleteTapped(id: "p2"))
        XCTAssertTrue(store.state.places.isEmpty)
        XCTAssertFalse(store.state.canSave)
    }

    func test_제목이_공백뿐이면_저장할_수_없다() async {
        let store = await loadedStore()
        await store.send(.titleChanged("   "))
        XCTAssertFalse(store.state.canSave)
    }

    func test_안_바꾸고_뒤로가면_모달이_안_뜬다() async {
        let store = await loadedStore()
        await store.send(.backTapped)
        await store.receive(.delegate(.dismissed))
        XCTAssertFalse(store.state.isBackModalPresented)
    }

    func test_바꾸고_뒤로가면_모달이_뜬다() async {
        let store = await loadedStore()
        await store.send(.titleChanged("새 제목"))
        await store.send(.backTapped)
        XCTAssertTrue(store.state.isBackModalPresented)
    }

    func test_지웠다_되살리면_변경이_없다() async {
        let store = await loadedStore()
        await store.send(.placeDeleteTapped(id: "p1"))
        XCTAssertTrue(store.state.hasChanges)
        await store.send(.undoTapped)
        XCTAssertFalse(store.state.hasChanges)
    }

    func test_저장에_성공하면_saved가_올라간다() async {
        let receivedVersion = LockIsolated(-1)
        let receivedPlaceIDs = LockIsolated<[String]>([])
        let store = await loadedStore { _, content, version in
            receivedVersion.withValue { $0 = version }
            receivedPlaceIDs.withValue { $0 = content.placeIDs }
            return threeStopCourse
        }
        await store.send(.saveTapped)
        await store.receive(\.saveResponse)
        await store.receive(.delegate(.saved(threeStopCourse)))
        XCTAssertEqual(receivedVersion.value, threeStopCourse.version)
        XCTAssertEqual(receivedPlaceIDs.value, ["p0", "p1", "p2"])
    }

    func test_저장이_409면_conflicted가_올라간다() async {
        let store = await loadedStore { _, _, _ in throw CourseError.conflict }
        await store.send(.saveTapped)
        await store.receive(\.saveResponse)
        await store.receive(.delegate(.conflicted))
    }

    func test_저장이_다른_에러면_화면에_남는다() async {
        let store = await loadedStore { _, _, _ in throw CourseError.network }
        await store.send(.saveTapped)
        await store.receive(\.saveResponse)
        XCTAssertFalse(store.state.isSaving)
        XCTAssertNotNil(store.state.toast)
    }

    func test_저장이_401이면_sessionExpired가_올라간다() async {
        let store = await loadedStore { _, _, _ in throw CourseError.unauthorized }
        await store.send(.saveTapped)
        await store.receive(\.saveResponse)
        await store.receive(.delegate(.sessionExpired))
    }

    func test_장소를_더하면_목록_뒤에_붙는다() async {
        let store = await loadedStore()
        let candidate = CoursePlaceCandidate.fixture(id: "p9")
        await store.send(.placesAdded([candidate]))
        XCTAssertEqual(store.state.places.last?.id, "p9")
    }

    func test_장소_추가_후_onAppear는_편집을_안_지운다() async {
        let fetchCount = LockIsolated(0)
        let store = TestStore(initialState: CourseEditFeature.State(dateCourseID: "1")) {
            CourseEditFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in
                fetchCount.withValue { $0 += 1 }
                return threeStopCourse
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.onAppear)
        await store.receive(\.courseResponse)
        XCTAssertEqual(fetchCount.value, 1)

        await store.send(.titleChanged("새 제목"))
        await store.send(.placesAdded([CoursePlaceCandidate.fixture(id: "p9")]))
        await store.send(.onAppear)

        XCTAssertEqual(store.state.title, "새 제목")
        XCTAssertEqual(store.state.places.map(\.id), ["p0", "p1", "p2", "p9"])
        XCTAssertEqual(fetchCount.value, 1)
    }

    func test_시간이_없는_코스는_시간칸이_비고_저장에_시간을_안_보낸다() async {
        let receivedTime = LockIsolated<DateComponents?>(DateComponents(hour: 99, minute: 0))
        let store = await loadedStore { _, content, _ in
            receivedTime.withValue { $0 = content.time }
            return threeStopCourse
        }
        XCTAssertNil(store.state.scheduledTime)
        XCTAssertNil(store.state.timeText)
        await store.send(.saveTapped)
        await store.receive(\.saveResponse)
        XCTAssertNil(receivedTime.value)
    }

    func test_tomorrow가_now의_다음날이다() {
        let calendar = Calendar.current
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 23, hour: 22, minute: 3)
        ) ?? Date.distantPast
        let state = CourseEditFeature.State(dateCourseID: "1", now: now)
        var seoul = Calendar(identifier: .gregorian)
        seoul.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
        let expected = seoul.dateComponents(
            [.year, .month, .day],
            from: seoul.date(byAdding: .day, value: 1, to: now) ?? now
        )
        let today = calendar.dateComponents([.year, .month, .day], from: now)

        XCTAssertEqual(state.tomorrow, expected)
        XCTAssertEqual(state.draftTime.hour, 22)
        XCTAssertEqual(state.draftTime.minute, 3)
        XCTAssertNotEqual(state.tomorrow, today)
    }

    func test_이미_고른_시간이_있으면_휠을_열어도_그_값이다() async {
        let calendar = Calendar.current
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 23, hour: 22, minute: 3)
        ) ?? Date.distantPast
        var initial = CourseEditFeature.State(dateCourseID: "1", now: now)
        initial.scheduledTime = DateComponents(hour: 15, minute: 30)
        let store = TestStore(initialState: initial) {
            CourseEditFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.timeFieldTapped) {
            $0.activeWheel = .time
            $0.draftTime = DateComponents(hour: 15, minute: 30)
        }
    }

    func test_로드된_오늘_날짜는_날짜_휠을_안_열면_유지된다() async {
        let calendar = Calendar.current
        let now = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 23, hour: 22, minute: 0)
        ) ?? Date.distantPast
        let todayDate = calendar.date(
            from: DateComponents(year: 2026, month: 8, day: 23)
        ) ?? Date.distantPast
        let course = makeCourse(
            stopCount: 3,
            legs: threeStopCourse.legs,
            scheduledDate: todayDate
        )
        let store = TestStore(initialState: CourseEditFeature.State(dateCourseID: course.id, now: now)) {
            CourseEditFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in course }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onAppear)
        await store.receive(\.courseResponse)

        XCTAssertEqual(store.state.scheduledDate, todayDate)
        XCTAssertNotEqual(store.state.tomorrow, calendar.dateComponents([.year, .month, .day], from: now))
    }

    func test_모달의_x는_화면에_남긴다() async {
        let store = await loadedStore()
        await store.send(.titleChanged("새 제목"))
        await store.send(.backTapped)
        await store.send(.backModalClosed)
        XCTAssertFalse(store.state.isBackModalPresented)
    }

    func test_모달의_아니요는_화면을_닫는다() async {
        let store = await loadedStore()
        await store.send(.titleChanged("새 제목"))
        await store.send(.backTapped)
        await store.send(.backModalDiscarded)
        await store.receive(.delegate(.dismissed))
    }

    func test_모달의_저장은_저장_흐름과_같다() async {
        let store = await loadedStore { _, _, _ in threeStopCourse }
        await store.send(.titleChanged("새 제목"))
        await store.send(.backTapped)
        await store.send(.backModalSaveTapped)
        await store.receive(\.saveResponse)
        await store.receive(.delegate(.saved(threeStopCourse)))
    }
}

// MARK: - Store

@MainActor
private func loadedStore(
    course: DateCourse = threeStopCourse,
    updateCourse: (
        @Sendable (String, DateCourseContent, Int) async throws -> DateCourse
    )? = nil
) async -> TestStoreOf<CourseEditFeature> {
    let store = TestStore(initialState: CourseEditFeature.State(dateCourseID: course.id)) {
        CourseEditFeature()
    } withDependencies: {
        $0.courseClient.course = { _ in course }
        if let updateCourse {
            $0.courseClient.updateCourse = updateCourse
        }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.onAppear)
    await store.receive(\.courseResponse)
    return store
}

// MARK: - Fixture

private let threeStopCourse = makeCourse(
    stopCount: 3,
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
        Domain.CourseLeg(walkingMinutes: 80, distanceMeters: 5300),
    ]
)

private func makeCourse(
    stopCount: Int,
    legs: [Domain.CourseLeg?],
    scheduledDate: Date = seoulDate(year: 2026, month: 8, day: 5),
    scheduledTime: DateComponents? = nil
) -> DateCourse {
    DateCourse(
        id: "1",
        title: "26.08.05 데이트",
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
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

private func seoulDate(year: Int, month: Int, day: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .gmt
    return calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date.distantPast
}
