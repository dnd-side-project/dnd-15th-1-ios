import ComposableArchitecture
import CoreKakaoMap
import Domain
@testable import Feature
import Foundation
import SharedDesignSystem
import SharedUtils
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

    func test_대중교통_값이_오면_대중교통만_보인다() async {
        let store = resultStore(course: transitCourse)
        XCTAssertEqual(store.state.timelineLegs.map(\.mode), [.walk, .transit])
        XCTAssertEqual(store.state.timelineLegs.map(\.duration), ["도보 20분", "대중교통 45분"])
        XCTAssertEqual(store.state.timelineLegs.map(\.distance), ["1.5 km", "5.2 km"])
    }

    func test_대중교통이_1시간을_넘으면_시간과_분으로_보인다() async {
        let store = resultStore(course: longTransitCourse)
        XCTAssertEqual(store.state.timelineLegs.map(\.duration), ["대중교통 1시간 40분"])
    }

    func test_대중교통이_섞이면_요약이_이동_약과_총으로_바뀐다() async {
        let store = resultStore(course: transitCourse)
        // 20분 + 45분, 1.5km + 5.2km
        XCTAssertEqual(store.state.summaryText, "3곳 · 이동 약 1시간 5분 · 총 6.7km")
    }

    func test_요약_거리는_구간마다_반올림한_거리의_합이다() async {
        let store = resultStore(course: roundingCourse)
        // 1250m 둘. 미터를 먼저 더하면 2.5km 지만 행에 보이는 1.3 + 1.3 이 맞다
        XCTAssertEqual(store.state.timelineLegs.map(\.distance), ["1.3 km", "1.3 km"])
        XCTAssertEqual(store.state.summaryText, "3곳 · 도보 약 20분 · 총 이동 2.6km")
    }

    func test_값을_못_받은_구간은_안내_문구를_보인다() async {
        let store = resultStore(course: missingFirstLegCourse)
        XCTAssertEqual(store.state.timelineLegs.count, 3)
        XCTAssertEqual(store.state.timelineLegs[0].mode, .unavailable)
        XCTAssertEqual(store.state.timelineLegs[0].duration, "")
        XCTAssertEqual(store.state.timelineLegs[0].distance, "이동 정보를 불러오지 못했어요")
        XCTAssertEqual(store.state.timelineLegs[1].duration, "도보 20분")
        XCTAssertEqual(store.state.timelineLegs[1].distance, "1.5 km")
        XCTAssertEqual(store.state.timelineLegs[2].duration, "도보 1시간 20분")
        XCTAssertEqual(store.state.timelineLegs[2].distance, "5.3 km")
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

    func test_경로선이_장소와_구간_경로를_순서대로_잇는다() async {
        let store = resultStore(course: routedCourse)
        let stops = routedCourse.stops.map(\.place.coordinate)
        XCTAssertEqual(
            store.state.routes.first?.coordinates,
            [stops[0], walkPointA, walkPointB, stops[1], transitPointA, transitPointB, stops[2]]
        )
    }

    func test_대중교통_좌표가_비면_도보_경로_대신_장소끼리_직선이다() async {
        let store = resultStore(course: emptyTransitPathCourse)
        XCTAssertEqual(
            store.state.routes.first?.coordinates,
            emptyTransitPathCourse.stops.map(\.place.coordinate)
        )
    }

    func test_값을_못_받은_구간은_장소끼리_직선이다() async {
        let store = resultStore(course: nilLegRoutedCourse)
        let stops = nilLegRoutedCourse.stops.map(\.place.coordinate)
        XCTAssertEqual(
            store.state.routes.first?.coordinates,
            [stops[0], stops[1], walkPointA, stops[2]]
        )
    }

    func test_첫_화면이_경로_선_전체를_담는다() async {
        let store = resultStore(course: detourCourse)
        await store.send(.mapSizeChanged(width: 390, visibleHeight: 400))
        let stops = detourCourse.stops.map(\.place.coordinate)
        let withRoute = MapZoom.fit(
            coordinates: [stops[0], detourPoint, stops[1]],
            anchor: stops[0],
            viewWidth: 390,
            visibleHeight: 400,
            maximum: MapCamera.multiPlaceZoom,
            focusRatio: MapZoom.mapFocusRatio
        )
        let stopsOnly = MapZoom.fit(
            coordinates: stops,
            anchor: stops[0],
            viewWidth: 390,
            visibleHeight: 400,
            maximum: MapCamera.multiPlaceZoom,
            focusRatio: MapZoom.mapFocusRatio
        )
        XCTAssertEqual(store.state.camera.center, stops[0])
        XCTAssertEqual(store.state.camera.zoomLevel, withRoute)
        XCTAssertNotEqual(withRoute, stopsOnly)
    }
}

@MainActor
final class CourseResultDelegateTests: XCTestCase {

    func test_코스_알리기를_누르면_토스트가_뜬다() async {
        let store = resultStore(course: threeStopCourse)
        store.dependencies.authClient.currentSession = {
            AuthSession(accessToken: "a", refreshToken: "r", userID: "user")
        }
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
        store.dependencies.authClient.currentSession = {
            AuthSession(accessToken: "a", refreshToken: "r", userID: "user")
        }
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
        store.dependencies.authClient.currentSession = {
            AuthSession(accessToken: "a", refreshToken: "r", userID: "user")
        }
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

    func test_수정을_누르면_수정시작_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = resultStore(course: threeStopCourse)
        store.dependencies.analyticsClient.track = { event in
            sent.withValue { $0.append(event) }
        }
        await store.send(.editTapped)
        await store.receive(.delegate(.editRequested(threeStopCourse)))
        await store.finish()
        XCTAssertEqual(sent.value, [.courseEditStarted])
    }

    func test_알리기를_누르면_알람_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = resultStore(course: threeStopCourse)
        store.dependencies.analyticsClient.track = { event in
            sent.withValue { $0.append(event) }
        }
        store.dependencies.authClient.currentSession = {
            AuthSession(accessToken: "a", refreshToken: "r", userID: "user-42")
        }
        store.dependencies.courseClient.notifyPartner = { _ in }
        await store.send(.notifyTapped) {
            $0.isNotifyingPartner = true
        }
        await store.receive(.partnerNotified(nil)) {
            $0.isNotifyingPartner = false
            $0.toast = ToastState(message: "상대에게 코스를 알렸어요")
        }
        await store.finish()
        XCTAssertEqual(sent.value, [.courseAlarmStarted(userID: "user-42")])
    }

    func test_뒤로가기를_누르면_dismissed가_올라간다() async {
        let store = resultStore(course: threeStopCourse)
        await store.send(.backTapped)
        await store.receive(.delegate(.dismissed))
    }
}

@MainActor
final class CourseResultDirectionsTests: XCTestCase {

    func test_도보_구간을_누르면_도보_길찾기를_연다() {
        let state = CourseResultFeature.State(
            course: directionsCourse(names: ["성수 카페", "서점", "역삼"], legs: [walkLeg, transitLeg]),
            dateCourseID: "1"
        )

        XCTAssertEqual(state.legDirections.count, 2)
        XCTAssertEqual(
            state.legDirections[0]?.appURL.absoluteString,
            "kakaomap://route?sp=37.5446,127.0557&ep=37.5172,127.0473&by=foot"
        )
        XCTAssertEqual(
            state.legDirections[0]?.webURL.absoluteString,
            "https://map.kakao.com/link/by/walk/"
                + "%EC%84%B1%EC%88%98%20%EC%B9%B4%ED%8E%98,37.5446,127.0557/"
                + "%EC%84%9C%EC%A0%90,37.5172,127.0473"
        )
    }

    func test_대중교통_구간을_누르면_대중교통_길찾기를_연다() {
        let state = CourseResultFeature.State(
            course: directionsCourse(names: ["성수 카페", "서점", "역삼"], legs: [walkLeg, transitLeg]),
            dateCourseID: "1"
        )

        XCTAssertEqual(
            state.legDirections[1]?.appURL.absoluteString,
            "kakaomap://route?sp=37.5172,127.0473&ep=37.4979,127.0276&by=publictransit"
        )
        XCTAssertEqual(
            state.legDirections[1]?.webURL.absoluteString,
            "https://map.kakao.com/link/by/traffic/"
                + "%EC%84%9C%EC%A0%90,37.5172,127.0473/"
                + "%EC%97%AD%EC%82%BC,37.4979,127.0276"
        )
    }

    func test_값을_못_받은_구간은_대중교통_길찾기를_연다() {
        let state = CourseResultFeature.State(
            course: directionsCourse(names: ["성수 카페", "서점", "역삼"], legs: [nil, transitLeg]),
            dateCourseID: "1"
        )

        XCTAssertEqual(
            state.legDirections[0]?.appURL.absoluteString,
            "kakaomap://route?sp=37.5446,127.0557&ep=37.5172,127.0473&by=publictransit"
        )
        XCTAssertEqual(
            state.legDirections[0]?.webURL.absoluteString,
            "https://map.kakao.com/link/by/traffic/"
                + "%EC%84%B1%EC%88%98%20%EC%B9%B4%ED%8E%98,37.5446,127.0557/"
                + "%EC%84%9C%EC%A0%90,37.5172,127.0473"
        )
    }

    func test_장소_이름의_쉼표와_슬래시는_공백으로_바꾼다() {
        let state = CourseResultFeature.State(
            course: directionsCourse(names: ["성수, 카페/2층", "서점", "역삼"], legs: [walkLeg, transitLeg]),
            dateCourseID: "1"
        )

        XCTAssertEqual(
            state.legDirections[0]?.webURL.absoluteString,
            "https://map.kakao.com/link/by/walk/"
                + "%EC%84%B1%EC%88%98%20%20%EC%B9%B4%ED%8E%98%202%EC%B8%B5,37.5446,127.0557/"
                + "%EC%84%9C%EC%A0%90,37.5172,127.0473"
        )
    }

    func test_길찾기_링크는_구간_수단을_읽어준다() {
        let state = CourseResultFeature.State(
            course: directionsCourse(names: ["성수 카페", "서점", "역삼"], legs: [walkLeg, transitLeg]),
            dateCourseID: "1"
        )
        XCTAssertEqual(
            state.timelineLegs.map(\.directionsAccessibilityLabel),
            ["도보 길찾기를 카카오맵으로 보기", "대중교통 길찾기를 카카오맵으로 보기"]
        )

        // 값을 못 받은 구간은 대중교통으로 열린다
        let missing = CourseResultFeature.State(
            course: directionsCourse(names: ["성수 카페", "서점", "역삼"], legs: [nil, transitLeg]),
            dateCourseID: "1"
        )
        XCTAssertEqual(missing.timelineLegs[0].directionsAccessibilityLabel, "대중교통 길찾기를 카카오맵으로 보기")
    }

    func test_길찾기_링크가_읽어주는_수단과_여는_수단이_같다() {
        // 도보 · 대중교통 · 값 없음을 다 거친다
        let states = [[walkLeg, transitLeg], [nil, transitLeg]].map { legs in
            CourseResultFeature.State(
                course: directionsCourse(names: ["성수 카페", "서점", "역삼"], legs: legs),
                dateCourseID: "1"
            )
        }
        let labelModes = states.flatMap(\.timelineLegs).map { leg in
            leg.directionsAccessibilityLabel.hasPrefix("대중교통") ? "publictransit" : "foot"
        }
        let urlModes = states.flatMap(\.legDirections).map { directions in
            directions?.appURL.absoluteString.components(separatedBy: "&by=").last ?? ""
        }

        XCTAssertEqual(labelModes, ["foot", "publictransit", "publictransit", "publictransit"])
        XCTAssertEqual(urlModes, labelModes)
    }

    func test_장소가_1곳이면_길찾기가_없다() {
        let state = CourseResultFeature.State(
            course: directionsCourse(names: ["성수 카페"], legs: []),
            dateCourseID: "1"
        )

        XCTAssertTrue(state.legDirections.isEmpty)
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

    func test_충돌하면_코스를_비우고_토스트와_함께_다시_읽는다() async {
        let store = resultStore(course: threeStopCourse)
        store.dependencies.courseClient.course = { _ in threeStopCourse }

        await store.send(.conflictReloadRequested) {
            $0.course = nil
            $0.loadState = .loading
            $0.toast = ToastState(message: "상대방이 먼저 바꿔서 최신 코스를 불러왔어요")
        }
        await store.receive(\.courseResponse)
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

private let transitCourse = makeCourse(
    stopCount: 3,
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
        Domain.CourseLeg(
            walkingMinutes: 80,
            distanceMeters: 5300,
            transit: Domain.CourseTransit(minutes: 45, distanceMeters: 5200, path: [])
        ),
    ]
)

private let longTransitCourse = makeCourse(
    stopCount: 2,
    legs: [
        Domain.CourseLeg(
            walkingMinutes: 150,
            distanceMeters: 9800,
            transit: Domain.CourseTransit(minutes: 100, distanceMeters: 9100, path: [])
        ),
    ]
)

private let roundingCourse = makeCourse(
    stopCount: 3,
    legs: [
        Domain.CourseLeg(walkingMinutes: 10, distanceMeters: 1250),
        Domain.CourseLeg(walkingMinutes: 10, distanceMeters: 1250),
    ]
)

private let walkPointA = Coordinate(latitude: 37.312, longitude: 126.905)
private let walkPointB = Coordinate(latitude: 37.315, longitude: 126.908)
private let transitPointA = Coordinate(latitude: 37.322, longitude: 126.915)
private let transitPointB = Coordinate(latitude: 37.326, longitude: 126.918)
/// 대중교통이 있는 구간에서는 그리면 안 되는 도보 경로 점
private let ignoredWalkPoint = Coordinate(latitude: 37.400, longitude: 127.000)

private let routedCourse = makeCourse(
    stopCount: 3,
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500, walkingPath: [walkPointA, walkPointB]),
        Domain.CourseLeg(
            walkingMinutes: 80,
            distanceMeters: 5300,
            walkingPath: [ignoredWalkPoint],
            transit: Domain.CourseTransit(
                minutes: 45,
                distanceMeters: 5200,
                path: [transitPointA, transitPointB]
            )
        ),
    ]
)

private let emptyTransitPathCourse = makeCourse(
    stopCount: 2,
    legs: [
        Domain.CourseLeg(
            walkingMinutes: 80,
            distanceMeters: 5300,
            walkingPath: [ignoredWalkPoint],
            transit: Domain.CourseTransit(minutes: 45, distanceMeters: 5200, path: [])
        ),
    ]
)

private let nilLegRoutedCourse = makeCourse(
    stopCount: 3,
    legs: [
        nil,
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500, walkingPath: [walkPointA]),
    ]
)

/// 두 장소보다 한참 남쪽으로 도는 경로 점. 장소만으로 맞춘 줌이면 잘린다
private let detourPoint = Coordinate(latitude: 37.5000, longitude: 126.9780)

private let detourCourse = DateCourse(
    id: "1",
    title: "26.08.05 데이트",
    scheduledDate: Date(timeIntervalSince1970: 0),
    scheduledTime: nil,
    status: .confirmed,
    version: 1,
    stops: [
        Domain.CourseStop(place: .fixture(id: "p0", latitude: 37.5665, longitude: 126.9780)),
        Domain.CourseStop(place: .fixture(id: "p1", latitude: 37.5565, longitude: 126.9780)),
    ],
    legs: [
        Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500, walkingPath: [detourPoint]),
    ]
)

private let walkLeg = Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500)

private let transitLeg = Domain.CourseLeg(
    walkingMinutes: 80,
    distanceMeters: 5300,
    transit: Domain.CourseTransit(minutes: 45, distanceMeters: 5200, path: [])
)

/// 좌표를 리터럴로 고정해 주소 글자를 그대로 맞춰 본다
private func directionsCourse(names: [String], legs: [Domain.CourseLeg?]) -> DateCourse {
    let coordinates = [
        Coordinate(latitude: 37.5446, longitude: 127.0557),
        Coordinate(latitude: 37.5172, longitude: 127.0473),
        Coordinate(latitude: 37.4979, longitude: 127.0276),
    ]
    return DateCourse(
        id: "1",
        title: "26.08.05 데이트",
        scheduledDate: Date(timeIntervalSince1970: 0),
        scheduledTime: nil,
        status: .confirmed,
        version: 1,
        stops: zip(names, coordinates).enumerated().map { index, pair in
            Domain.CourseStop(
                place: .fixture(
                    id: "p\(index)",
                    name: pair.0,
                    latitude: pair.1.latitude,
                    longitude: pair.1.longitude
                )
            )
        },
        legs: legs
    )
}

private let mixedCategoryCourse = DateCourse(
    id: "1",
    title: "26.08.05 데이트",
    scheduledDate: Date(timeIntervalSince1970: 0),
    scheduledTime: nil,
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
    scheduledDate: Date(timeIntervalSince1970: 0),
    scheduledTime: nil,
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

private func makeCourse(
    stopCount: Int,
    legs: [Domain.CourseLeg?],
    scheduledTime: DateComponents? = nil
) -> DateCourse {
    DateCourse(
        id: "1",
        title: "26.08.05 데이트",
        scheduledDate: seoulDate(year: 2026, month: 8, day: 5),
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
        placeID: "p0",
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
    scheduledDate: Date(timeIntervalSince1970: 0),
    scheduledTime: nil,
    status: .confirmed,
    version: 0,
    stops: [originFixtureStop],
    legs: []
)

private let emptyFixtureCourse = DateCourse(
    id: "42",
    title: "t",
    scheduledDate: Date(timeIntervalSince1970: 0),
    scheduledTime: nil,
    status: .confirmed,
    version: 0,
    stops: [],
    legs: []
)

// MARK: - 내 위치 점

@MainActor
final class CourseResultUserLocationTests: XCTestCase {

    func test_코스_상세_지도가_보이면_흐름의_좌표로_점을_그린다() async {
        let here = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let (stream, continuation) = AsyncStream<Coordinate?>.makeStream()
        let store = TestStore(
            initialState: CourseResultFeature.State(course: threeStopCourse, dateCourseID: "1")
        ) {
            CourseResultFeature()
        } withDependencies: {
            $0.locationClient.coordinateUpdates = { stream }
        }

        await store.send(.mapAppeared)
        continuation.yield(here)
        await store.receive(\.userLocationChanged) {
            $0.userLocation = here
        }

        continuation.finish()
        await store.finish()
    }

    func test_코스_상세_지도가_사라지면_흐름을_끊는다() async {
        let here = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let (stream, continuation) = AsyncStream<Coordinate?>.makeStream()
        let store = TestStore(
            initialState: CourseResultFeature.State(course: threeStopCourse, dateCourseID: "1")
        ) {
            CourseResultFeature()
        } withDependencies: {
            $0.locationClient.coordinateUpdates = { stream }
        }

        let task = await store.send(.mapAppeared)
        continuation.yield(here)
        await store.receive(\.userLocationChanged) {
            $0.userLocation = here
        }

        // 흐름은 아직 열려 있다. 뷰의 task 가 취소되어 효과가 끊겨야 이 테스트가 끝난다
        await task.cancel()
    }

    func test_코스_상세_다시_들어오면_새_좌표가_올_때까지_점을_지운다() async {
        let here = Coordinate(latitude: 37.5665, longitude: 126.9780)
        let (stream, continuation) = AsyncStream<Coordinate?>.makeStream()
        var state = CourseResultFeature.State(course: threeStopCourse, dateCourseID: "1")
        state.userLocation = here
        let store = TestStore(initialState: state) {
            CourseResultFeature()
        } withDependencies: {
            $0.locationClient.coordinateUpdates = { stream }
        }

        let task = await store.send(.mapAppeared) {
            $0.userLocation = nil
        }

        continuation.finish()
        await task.finish()
    }
}
