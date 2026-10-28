import CoreLocation
import Foundation
import SharedUtils
import UIKit
import XCTest

@testable import Data

@MainActor
final class LocationUpdateTrackerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let here = Coordinate(latitude: 37.5665, longitude: 126.9780)

    // MARK: - 켜고 끄기

    func test_허용이고_정확한_위치면_10m_간격으로_갱신을_켠다() {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, sent) = makeTracker(manager: manager)

        tracker.start()

        XCTAssertEqual(manager.startCount, 1)
        XCTAssertEqual(manager.desiredAccuracy, kCLLocationAccuracyNearestTenMeters)
        XCTAssertEqual(manager.distanceFilter, 10)
        XCTAssertEqual(sent.values, [])
    }

    func test_권한이_없으면_없음을_보내고_갱신을_켜지_않는다() {
        let manager = FakeLocationManager(status: .denied)
        let (tracker, sent) = makeTracker(manager: manager)

        tracker.start()

        XCTAssertEqual(manager.startCount, 0)
        XCTAssertEqual(sent.values, [nil])
    }

    func test_권한_알림이_다시_와도_갱신은_한_번만_켠다() {
        // 실제 관리자는 만들어진 직후 권한 알림을 한 번 보낸다
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, _) = makeTracker(manager: manager)

        tracker.start()
        tracker.authorizationChanged()

        XCTAssertEqual(manager.startCount, 1)
    }

    func test_권한이_꺼지면_없음을_보내고_갱신을_끈다() {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, sent) = makeTracker(manager: manager)
        tracker.start()

        manager.authorizationStatus = .denied
        tracker.authorizationChanged()

        XCTAssertEqual(manager.stopCount, 1)
        XCTAssertEqual(sent.values, [nil])
    }

    func test_권한이_생기면_갱신을_켠다() {
        let manager = FakeLocationManager(status: .notDetermined)
        let (tracker, _) = makeTracker(manager: manager)
        tracker.start()
        XCTAssertEqual(manager.startCount, 0)

        manager.authorizationStatus = .authorizedWhenInUse
        tracker.authorizationChanged()

        XCTAssertEqual(manager.startCount, 1)
    }

    // MARK: - 좌표

    func test_쓸_수_있는_좌표를_보낸다() {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, sent) = makeTracker(manager: manager)
        tracker.start()

        tracker.received([location(age: 1)])

        XCTAssertEqual(sent.values, [here])
    }

    func test_버릴_좌표는_보내지_않는다() {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, sent) = makeTracker(manager: manager)
        tracker.start()

        tracker.received([location(age: 11)])

        XCTAssertEqual(sent.values, [])
    }

    // MARK: - 실패

    func test_권한_거부로_실패하면_없음을_보내고_갱신을_끈다() {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, sent) = makeTracker(manager: manager)
        tracker.start()

        tracker.failed(with: CLError(.denied))

        XCTAssertEqual(manager.stopCount, 1)
        XCTAssertEqual(sent.values, [nil])
    }

    func test_그밖의_실패는_마지막_점을_둔다() {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, sent) = makeTracker(manager: manager)
        tracker.start()
        tracker.received([location(age: 1)])

        tracker.failed(with: CLError(.locationUnknown))

        XCTAssertEqual(manager.stopCount, 0)
        XCTAssertEqual(sent.values, [here])
    }

    // MARK: - 앱 상태

    func test_앱이_뒤로_가면_갱신을_멈춘다() {
        let center = NotificationCenter()
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, sent) = makeTracker(manager: manager, center: center)
        tracker.start()

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        XCTAssertEqual(manager.stopCount, 1)
        XCTAssertEqual(sent.values, [])
    }

    func test_앱이_앞으로_오면_갱신을_다시_켠다() {
        let center = NotificationCenter()
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, _) = makeTracker(manager: manager, center: center)
        tracker.start()

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        XCTAssertEqual(manager.startCount, 2)
    }

    func test_뒤에_있는_동안_권한이_꺼졌으면_앞으로_올_때_없음을_보낸다() {
        let center = NotificationCenter()
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, sent) = makeTracker(manager: manager, center: center)
        tracker.start()

        center.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        manager.authorizationStatus = .denied
        center.post(name: UIApplication.willEnterForegroundNotification, object: nil)

        XCTAssertEqual(manager.startCount, 1)
        XCTAssertEqual(sent.values, [nil])
    }

    // MARK: - 끝내기

    func test_흐름이_시작되기_전에_끝나면_갱신을_켜지_않는다() {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let (tracker, _) = makeTracker(manager: manager)

        tracker.stop()
        tracker.start()

        XCTAssertEqual(manager.startCount, 0)
        XCTAssertNil(manager.delegate)
    }

    func test_흐름이_끝나면_갱신을_멈추고_관리자를_놓는다() async {
        let manager = FakeLocationManager(status: .authorizedWhenInUse)
        let started = expectation(description: "갱신을 켰다")
        let stopped = expectation(description: "갱신을 멈췄다")
        manager.onStart = { started.fulfill() }
        manager.onStop = { stopped.fulfill() }
        let stream = LocationUpdateTracker.coordinateUpdates(
            makeManager: { manager },
            notificationCenter: NotificationCenter()
        )
        let task = Task {
            for await _ in stream {}
        }

        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        await fulfillment(of: [stopped], timeout: 1)

        XCTAssertEqual(manager.stopCount, 1)
        XCTAssertNil(manager.delegate)
    }

    // MARK: - 도우미

    private func makeTracker(
        manager: FakeLocationManager,
        center: NotificationCenter = NotificationCenter()
    ) -> (LocationUpdateTracker, SentValues) {
        let sent = SentValues()
        let now = self.now
        let tracker = LocationUpdateTracker(
            makeManager: { manager },
            notificationCenter: center,
            maxAge: .seconds(10),
            now: { now },
            send: { value in
                MainActor.assumeIsolated { sent.values.append(value) }
            }
        )
        return (tracker, sent)
    }

    private func location(age: TimeInterval) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: here.latitude, longitude: here.longitude),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: now.addingTimeInterval(-age)
        )
    }
}

/// 흐름이 보낸 값을 차례대로 모은다
@MainActor
private final class SentValues {
    var values: [Coordinate?] = []
}

/// 켜고 끈 횟수를 세는 가짜 관리자. delegate 를 강하게 쥐어 `stop()` 이 풀었는지 볼 수 있다
@MainActor
private final class FakeLocationManager: LocationUpdateManaging {
    // swiftlint:disable:next weak_delegate
    var delegate: (any CLLocationManagerDelegate)?
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    var distanceFilter: CLLocationDistance = kCLDistanceFilterNone
    var authorizationStatus: CLAuthorizationStatus
    var accuracyAuthorization: CLAccuracyAuthorization = .fullAccuracy
    private(set) var startCount = 0
    private(set) var stopCount = 0
    var onStart: () -> Void = {}
    var onStop: () -> Void = {}

    init(status: CLAuthorizationStatus) {
        authorizationStatus = status
    }

    func startUpdatingLocation() {
        startCount += 1
        onStart()
    }

    func stopUpdatingLocation() {
        stopCount += 1
        onStop()
    }
}
