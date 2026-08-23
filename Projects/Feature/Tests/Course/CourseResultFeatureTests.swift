import ComposableArchitecture
import Domain
@testable import Feature
import Foundation
import SharedDesignSystem
import XCTest

@MainActor
final class CourseResultSummaryTests: XCTestCase {

    func test_장소_3곳이면_요약이_구간합으로_만들어진다() async {
        let store = resultStore(course: threeStopCourse)
        XCTAssertEqual(store.state.summaryText, "3곳 · 도보 약 1시간 40분 · 총 이동 6.8km")
    }

    func test_구간_거리는_띄어_쓰고_요약은_붙여_쓴다() async {
        let store = resultStore(course: threeStopCourse)
        XCTAssertEqual(store.state.summaryText, "3곳 · 도보 약 1시간 40분 · 총 이동 6.8km")
        XCTAssertEqual(store.state.timelineLegs.map(\.distance), ["1.5 km", "5.3 km"])
    }

    func test_장소가_2곳이면_요약과_구간이_같이_줄어든다() async {
        let store = resultStore(course: twoStopCourse)
        XCTAssertEqual(store.state.summaryText, "2곳 · 도보 약 20분 · 총 이동 1.5km")
        XCTAssertEqual(store.state.timelineLegs.count, 1)
    }

    func test_30분_넘는_구간에만_긴_구간_표시가_붙는다() async {
        let store = resultStore(course: threeStopCourse)
        XCTAssertEqual(store.state.timelineLegs.map(\.isLong), [false, true])
    }

    func test_도보값을_못_받은_구간은_글자만_비운다() async {
        let store = resultStore(course: missingFirstLegCourse)
        XCTAssertEqual(store.state.timelineLegs.count, 3)
        XCTAssertEqual(store.state.timelineLegs[0].duration, "")
        XCTAssertEqual(store.state.timelineLegs[0].distance, "")
        XCTAssertFalse(store.state.timelineLegs[0].isLong)
        XCTAssertEqual(store.state.timelineLegs[1].duration, "도보 20분")
        XCTAssertEqual(store.state.timelineLegs[1].distance, "1.5 km")
        XCTAssertFalse(store.state.timelineLegs[1].isLong)
        XCTAssertEqual(store.state.timelineLegs[2].duration, "도보 1시간 20분")
        XCTAssertEqual(store.state.timelineLegs[2].distance, "5.3 km")
        XCTAssertTrue(store.state.timelineLegs[2].isLong)
        XCTAssertEqual(store.state.summaryText, "4곳 · 도보 약 1시간 40분 · 총 이동 6.8km")
    }

    func test_장소가_0곳이면_요약과_하단_버튼이_없다() async {
        let store = resultStore(course: emptyCourse)
        XCTAssertNil(store.state.summaryText)
        XCTAssertFalse(store.state.showsNotifyButton)
    }
}

@MainActor
final class CourseResultMapTests: XCTestCase {

    func test_카메라_중심이_1번_장소다() async {
        let store = resultStore(course: threeStopCourse)
        await store.send(.mapSizeChanged(width: 390, visibleHeight: 400))
        XCTAssertEqual(store.state.camera.center, threeStopCourse.stops[0].place.coordinate)
    }

    func test_사용자가_민_카메라를_기억한다() async {
        let store = resultStore(course: threeStopCourse)
        let moved = MapCamera(
            center: Coordinate(latitude: 37.5, longitude: 127.0),
            zoomLevel: 12
        )
        await store.send(.cameraChanged(moved)) {
            $0.camera = moved
            $0.hasUserMovedCamera = true
        }
    }

    func test_사용자가_민_뒤에는_줌을_다시_안_맞춘다() async {
        let store = resultStore(course: threeStopCourse)
        await store.send(.mapSizeChanged(width: 390, visibleHeight: 400))
        let fitted = store.state.camera
        let moved = MapCamera(
            center: Coordinate(latitude: 37.5, longitude: 127.0),
            zoomLevel: 12
        )
        await store.send(.cameraChanged(moved)) {
            $0.camera = moved
            $0.hasUserMovedCamera = true
        }
        await store.send(.mapSizeChanged(width: 390, visibleHeight: 400))
        XCTAssertEqual(store.state.camera, moved)
        XCTAssertNotEqual(moved, fitted)
    }

    func test_줌이_지도_초점_비율을_쓴다() async {
        let store = resultStore(course: southStopCourse)
        await store.send(.mapSizeChanged(width: 390, visibleHeight: 400))
        let coordinates = southStopCourse.stops.map(\.place.coordinate)
        let expected = MapZoom.fit(
            coordinates: coordinates,
            anchor: coordinates[0],
            viewWidth: 390,
            visibleHeight: 400,
            maximum: MapCamera.multiPlaceZoom,
            focusRatio: MapZoom.mapFocusRatio
        )
        let centered = MapZoom.fit(
            coordinates: coordinates,
            anchor: coordinates[0],
            viewWidth: 390,
            visibleHeight: 400,
            maximum: MapCamera.multiPlaceZoom
        )
        XCTAssertEqual(store.state.camera.zoomLevel, expected)
        XCTAssertNotEqual(expected, centered)
    }

    func test_경로선_좌표가_핀_순서와_같다() async {
        let store = resultStore(course: threeStopCourse)
        XCTAssertEqual(
            store.state.routes.first?.coordinates,
            threeStopCourse.stops.map(\.place.coordinate)
        )
    }

    func test_장소마다_카테고리핀과_번호물방울을_겹친다() async {
        let store = resultStore(course: threeStopCourse)
        XCTAssertEqual(
            store.state.markers.map(\.id),
            ["p0", "numbered:p0", "p1", "numbered:p1", "p2", "numbered:p2"]
        )
        XCTAssertEqual(
            store.state.markers.map(\.kind),
            [
                .category(.food), .numbered(1),
                .category(.food), .numbered(2),
                .category(.food), .numbered(3),
            ]
        )
        XCTAssertEqual(
            store.state.markers.map(\.coordinate),
            threeStopCourse.stops.flatMap { stop in
                [stop.place.coordinate, stop.place.coordinate]
            }
        )
    }

    func test_카테고리핀은_장소_카테고리를_따른다() async {
        let store = resultStore(course: mixedCategoryCourse)
        XCTAssertEqual(
            store.state.markers.map(\.kind),
            [
                .category(.cafe), .numbered(1),
                .category(.tourism), .numbered(2),
            ]
        )
    }

    func test_장소가_0곳이면_핀도_경로선도_없다() async {
        let store = resultStore(course: emptyCourse)
        XCTAssertTrue(store.state.markers.isEmpty)
        XCTAssertTrue(store.state.routes.isEmpty)
    }
}

@MainActor
final class CourseResultDelegateTests: XCTestCase {

    func test_코스_알리기를_누르면_토스트가_뜬다() async {
        let store = resultStore(course: threeStopCourse)
        store.dependencies.courseClient.notifyPartner = { id in
            XCTAssertEqual(id, "1")
        }
        await store.send(.notifyTapped) {
            $0.isNotifyingPartner = true
        }
        await store.receive(.partnerNotified(nil)) {
            $0.isNotifyingPartner = false
            $0.toast = ToastState(message: "상대에게 코스를 알렸어요")
        }
    }

    func test_코스_알리기가_실패하면_토스트가_뜬다() async {
        let store = resultStore(course: threeStopCourse)
        store.dependencies.courseClient.notifyPartner = { _ in throw CourseError.network }
        await store.send(.notifyTapped) {
            $0.isNotifyingPartner = true
        }
        await store.receive(.partnerNotified(.network)) {
            $0.isNotifyingPartner = false
            $0.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
        }
    }

    func test_코스_알리기가_만료면_sessionExpired가_올라간다() async {
        let store = resultStore(course: threeStopCourse)
        store.dependencies.courseClient.notifyPartner = { _ in throw CourseError.unauthorized }
        await store.send(.notifyTapped) {
            $0.isNotifyingPartner = true
        }
        await store.receive(.partnerNotified(.unauthorized)) {
            $0.isNotifyingPartner = false
        }
        await store.receive(.delegate(.sessionExpired))
        XCTAssertNil(store.state.toast)
    }

    func test_코스_알리는_중에는_다시_안_부른다() async {
        var initial = CourseResultFeature.State(course: threeStopCourse, dateCourseID: "1")
        initial.isNotifyingPartner = true
        let store = TestStore(initialState: initial) {
            CourseResultFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        let callCount = LockIsolated(0)
        store.dependencies.courseClient.notifyPartner = { _ in
            callCount.withValue { $0 += 1 }
        }
        await store.send(.notifyTapped)
        XCTAssertEqual(callCount.value, 0)
    }

    func test_수정을_누르면_editRequested가_올라간다() async {
        let store = resultStore(course: threeStopCourse)
        await store.send(.editTapped)
        await store.receive(.delegate(.editRequested(threeStopCourse)))
    }

    func test_뒤로가기를_누르면_dismissed가_올라간다() async {
        let store = resultStore(course: threeStopCourse)
        await store.send(.backTapped)
        await store.receive(.delegate(.dismissed))
    }
}

@MainActor
final class CourseResultLoadTests: XCTestCase {

    func test_재진입이면_코스를_받아_그린다() async {
        let store = TestStore(
            initialState: CourseResultFeature.State(course: nil, dateCourseID: "1")
        ) {
            CourseResultFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in threeStopCourse }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.onAppear)
        await store.receive(\.courseResponse.success) {
            $0.course = threeStopCourse
            $0.loadState = .loaded
        }
    }

    func test_다시_읽기를_시키면_코스가_있어도_받는다() async {
        let updated = twoStopCourse
        let store = TestStore(
            initialState: CourseResultFeature.State(course: threeStopCourse, dateCourseID: "1")
        ) {
            CourseResultFeature()
        } withDependencies: {
            $0.courseClient.course = { id in
                XCTAssertEqual(id, "1")
                return updated
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.reloadRequested)
        await store.receive(\.courseResponse.success) {
            $0.course = updated
            $0.loadState = .loaded
        }
    }

    func test_다시_읽기가_실패하면_옛_코스를_두고_토스트를_띄운다() async {
        let store = TestStore(
            initialState: CourseResultFeature.State(course: threeStopCourse, dateCourseID: "1")
        ) {
            CourseResultFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in throw CourseError.network }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.reloadRequested)
        await store.receive(\.courseResponse.failure) {
            $0.toast = ToastState(message: "잠시 뒤 다시 시도해주세요")
        }
        XCTAssertEqual(store.state.course, threeStopCourse)
        XCTAssertEqual(store.state.loadState, .loaded)
    }

    func test_다시_읽기가_만료면_sessionExpired가_올라간다() async {
        let store = TestStore(
            initialState: CourseResultFeature.State(course: threeStopCourse, dateCourseID: "1")
        ) {
            CourseResultFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in throw CourseError.unauthorized }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.reloadRequested)
        await store.receive(\.courseResponse.failure)
        await store.receive(.delegate(.sessionExpired))
        XCTAssertEqual(store.state.course, threeStopCourse)
        XCTAssertEqual(store.state.loadState, .loaded)
        XCTAssertNil(store.state.toast)
    }

    func test_조회가_만료면_sessionExpired가_올라간다() async {
        let store = TestStore(
            initialState: CourseResultFeature.State(course: nil, dateCourseID: "1")
        ) {
            CourseResultFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in throw CourseError.unauthorized }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.onAppear)
        await store.receive(.delegate(.sessionExpired))
    }
}

// MARK: - Store

@MainActor
private func resultStore(course: DateCourse) -> TestStoreOf<CourseResultFeature> {
    let store = TestStore(
        initialState: CourseResultFeature.State(course: course, dateCourseID: "1")
    ) {
        CourseResultFeature()
    }
    store.exhaustivity = .off(showSkippedAssertions: false)
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

private let twoStopCourse = makeCourse(
    stopCount: 2,
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
    ]
)

private let emptyCourse = makeCourse(stopCount: 0, legs: [])

private let missingFirstLegCourse = makeCourse(
    stopCount: 4,
    legs: [
        nil,
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
        Domain.CourseLeg(walkingMinutes: 80, distanceMeters: 5300),
    ]
)

private let mixedCategoryCourse = DateCourse(
    id: "1",
    title: "26.08.05 데이트",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 1,
    stops: [
        Domain.CourseStop(
            place: .fixture(id: "p0", category: .cafe, latitude: 37.5665, longitude: 126.9780)
        ),
        Domain.CourseStop(
            place: .fixture(id: "p1", category: .tourism, latitude: 37.5565, longitude: 126.9780)
        ),
    ],
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
    ]
)

/// 1번보다 남쪽 한 곳. 한가운데 초점과 지도 초점 비율에서 줌이 갈라진다
private let southStopCourse = DateCourse(
    id: "1",
    title: "26.08.05 데이트",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 1,
    stops: [
        Domain.CourseStop(
            place: .fixture(id: "p0", latitude: 37.5665, longitude: 126.9780)
        ),
        Domain.CourseStop(
            place: .fixture(id: "p1", latitude: 37.5565, longitude: 126.9780)
        ),
    ],
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
    ]
)

private func makeCourse(stopCount: Int, legs: [Domain.CourseLeg?]) -> DateCourse {
    DateCourse(
        id: "1",
        title: "26.08.05 데이트",
        scheduledAt: Date(timeIntervalSince1970: 0),
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

@MainActor
final class CourseResultOriginTests: XCTestCase {

    func test_코스를_짜서_들어오면_수정과_알리기가_보인다() {
        let state = CourseResultFeature.State(
            course: originFixtureCourse,
            dateCourseID: "42"
        )

        XCTAssertTrue(state.showsEditButton)
        XCTAssertTrue(state.showsNotifyButton)
    }

    func test_지난데이트로_들어오면_수정과_알리기가_없다() {
        let state = CourseResultFeature.State(
            course: originFixtureCourse,
            dateCourseID: "42",
            origin: .pastDate
        )

        XCTAssertFalse(state.showsEditButton)
        XCTAssertFalse(state.showsNotifyButton)
    }

    func test_장소가_없으면_코스를_짜서_들어와도_알리기가_없다() {
        let state = CourseResultFeature.State(
            course: emptyFixtureCourse,
            dateCourseID: "42"
        )

        XCTAssertFalse(state.showsNotifyButton)
    }
}

// MARK: - Origin Fixture

private let originFixtureStop = Domain.CourseStop(
    place: Place(
        id: "p0",
        kakaoPlaceID: nil,
        name: "장소",
        category: .food,
        address: "주소",
        roadAddress: "도로명",
        coordinate: Coordinate(latitude: 37.5, longitude: 127.0),
        bookmarkCount: 0,
        thumbnailURLs: []
    )
)

private let originFixtureCourse = DateCourse(
    id: "42",
    title: "t",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 0,
    stops: [originFixtureStop],
    legs: []
)

private let emptyFixtureCourse = DateCourse(
    id: "42",
    title: "t",
    scheduledAt: Date(timeIntervalSince1970: 0),
    status: .confirmed,
    version: 0,
    stops: [],
    legs: []
)
