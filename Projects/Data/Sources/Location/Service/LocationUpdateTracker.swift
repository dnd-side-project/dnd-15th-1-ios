import CoreLocation
import Foundation
import SharedUtils
import UIKit

/// 화면 하나가 내 위치를 계속 받는 동안 위치 관리자 하나를 붙든다.
///
/// 권한을 요청하지 않는다. 권한이 없거나 대략적 위치면 `nil` 을 보내고 갱신을 끈다.
/// 앱이 뒤로 가면 갱신만 멈추고, 앞으로 오면 권한을 다시 본다.
/// 관리자는 `start()` 에서 메인 액터로 만든다. 그래서 delegate 도 메인에서 불린다
@MainActor
final class LocationUpdateTracker: NSObject {
    typealias ManagerMaker = @MainActor @Sendable () -> any LocationUpdateManaging

    private let makeManager: ManagerMaker
    private let notificationCenter: NotificationCenter
    private let maxAge: Duration
    private let now: @Sendable () -> Date
    private let send: @Sendable (Coordinate?) -> Void

    private var manager: (any LocationUpdateManaging)?
    private var observers: [any NSObjectProtocol] = []
    private var isUpdating = false
    private var isInBackground = false
    /// 흐름이 시작되기 전에 끝나면 `stop()` 이 `start()` 보다 먼저 돈다. 그때 관리자를 안 만든다
    private var isStopped = false

    nonisolated init(
        makeManager: @escaping ManagerMaker,
        notificationCenter: NotificationCenter,
        maxAge: Duration,
        now: @escaping @Sendable () -> Date,
        send: @escaping @Sendable (Coordinate?) -> Void
    ) {
        self.makeManager = makeManager
        self.notificationCenter = notificationCenter
        self.maxAge = maxAge
        self.now = now
        self.send = send
        super.init()
    }

    func start() {
        guard !isStopped, manager == nil else { return }
        let manager = makeManager()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        self.manager = manager
        observeAppLifecycle()
        authorizationChanged()
    }

    func stop() {
        isStopped = true
        stopUpdating()
        manager?.delegate = nil
        manager = nil
        for observer in observers {
            notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    /// 권한이 바뀔 때마다, 그리고 앱이 앞으로 올 때 다시 정한다
    func authorizationChanged() {
        guard let manager else { return }
        let canTrack = LocationUpdatePolicy.canTrack(
            status: manager.authorizationStatus,
            accuracy: manager.accuracyAuthorization
        )
        guard canTrack else {
            stopUpdating()
            send(nil)
            return
        }
        guard !isInBackground, !isUpdating else { return }
        manager.startUpdatingLocation()
        isUpdating = true
    }

    func received(_ locations: [CLLocation]) {
        guard isUpdating, let location = locations.last else { return }
        let isUsable = LocationUpdatePolicy.accepts(
            horizontalAccuracy: location.horizontalAccuracy,
            age: now().timeIntervalSince(location.timestamp),
            maxAge: maxAge
        )
        guard isUsable else { return }
        send(
            Coordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
        )
    }

    /// 권한 거부만 점을 지운다. 잠깐 못 잡은 실패는 마지막 점을 그대로 둔다
    func failed(with error: any Error) {
        guard (error as? CLError)?.code == .denied else { return }
        stopUpdating()
        send(nil)
    }

    private func stopUpdating() {
        guard isUpdating else { return }
        manager?.stopUpdatingLocation()
        isUpdating = false
    }

    private func enterBackground() {
        isInBackground = true
        stopUpdating()
    }

    private func enterForeground() {
        isInBackground = false
        authorizationChanged()
    }

    /// 지도 엔진과 같은 방식으로 앱 상태를 직접 듣는다(`KakaoMapView.swift` 의 `observeAppLifecycle`)
    private func observeAppLifecycle() {
        observers = [
            notificationCenter.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // `queue: .main` 이라 메인 스레드가 보장된다
                MainActor.assumeIsolated {
                    self?.enterBackground()
                }
            },
            notificationCenter.addObserver(
                forName: UIApplication.willEnterForegroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.enterForeground()
                }
            },
        ]
    }
}

extension LocationUpdateTracker: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            authorizationChanged()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        MainActor.assumeIsolated {
            received(locations)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: any Error
    ) {
        MainActor.assumeIsolated {
            failed(with: error)
        }
    }
}

extension LocationUpdateTracker {
    /// 흐름 하나에 위치 관리자 하나. 흐름이 끝나면 갱신을 멈추고 관찰을 풀고 관리자를 놓는다
    nonisolated static func coordinateUpdates(
        makeManager: @escaping ManagerMaker = { CLLocationManager() },
        notificationCenter: NotificationCenter = .default,
        maxAge: Duration = .seconds(10),
        now: @escaping @Sendable () -> Date = { Date() }
    ) -> AsyncStream<Coordinate?> {
        // 점은 마지막 값만 의미가 있다. 늦게 읽어도 옛 좌표를 차례로 그리지 않는다
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let tracker = LocationUpdateTracker(
                makeManager: makeManager,
                notificationCenter: notificationCenter,
                maxAge: maxAge,
                now: now,
                send: { continuation.yield($0) }
            )
            continuation.onTermination = { _ in
                Task { @MainActor in tracker.stop() }
            }
            Task { @MainActor in tracker.start() }
        }
    }
}
