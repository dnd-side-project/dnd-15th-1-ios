import CoreLocation
import Domain
import Foundation
import SharedUtils

/// `CLLocationManager` 를 한 번짜리 `async` 호출로 감싼다.
///
/// `CLLocationManager` 는 자기를 만든 스레드에서 delegate 를 부른다. 메인에서 만들고
/// 메인에서만 만지므로 continuation 을 지키는 데 락이 필요 없다
@MainActor
final class SystemLocationProvider: NSObject {
    private let manager = CLLocationManager()
    private let maxCacheAge: Duration
    private var authorizationContinuation: CheckedContinuation<LocationAuthorization, Never>?
    private var coordinateContinuation: CheckedContinuation<Coordinate, Error>?
    private var isRequestingCoordinate = false

    init(maxCacheAge: Duration = .seconds(10)) {
        self.maxCacheAge = maxCacheAge
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func authorization() -> LocationAuthorization {
        Self.mapped(manager.authorizationStatus)
    }

    func requestAuthorization() async -> LocationAuthorization {
        let current = Self.mapped(manager.authorizationStatus)
        // 이미 정해졌으면 시스템 창이 안 뜬다. 기다리면 영영 안 깨어난다
        guard current == .notDetermined else { return current }
        // 요청이 겹치면 앞의 것을 버린다. 둘 다 기다리게 두면 재개가 새어 나간다
        authorizationContinuation?.resume(returning: current)
        authorizationContinuation = nil

        let timer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            self?.timeoutPendingAuthorization()
        }
        defer { timer.cancel() }

        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentCoordinate(timeout: Duration) async throws -> Coordinate {
        guard Self.mapped(manager.authorizationStatus) == .authorized else {
            throw LocationError.denied
        }
        // 지도 화면은 최근 좌표를 이미 들고 있는 때가 많다. 그때 새로 재면 얻는 것이 없다
        if let cached = manager.location,
           // 오차가 음수면 좌표를 못 잡았다는 뜻이다. 그 값은 0,0 이라 지도가 엉뚱한 데로 간다
           cached.horizontalAccuracy >= 0,
           Self.isCacheFresh(age: Date().timeIntervalSince(cached.timestamp), maxAge: maxCacheAge) {
            return Coordinate(
                latitude: cached.coordinate.latitude,
                longitude: cached.coordinate.longitude
            )
        }

        let timer = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            self?.failPending()
        }
        defer { timer.cancel() }

        return try await withCheckedThrowingContinuation { continuation in
            // 앞 요청이 아직 안 끝났으면 그것을 실패로 닫고 자리를 넘긴다
            coordinateContinuation?.resume(throwing: LocationError.unavailable)
            coordinateContinuation = continuation
            // 이미 도는 측위 위에 다시 요청하면 CoreLocation 이 답을 안 준다
            if !isRequestingCoordinate {
                isRequestingCoordinate = true
                manager.requestLocation()
            }
        }
    }

    private func timeoutPendingAuthorization() {
        guard let continuation = authorizationContinuation else { return }
        authorizationContinuation = nil
        continuation.resume(returning: Self.mapped(self.manager.authorizationStatus))
    }

    /// 시간 상한이 지났을 때 기다리는 쪽을 깨운다. 이미 답이 왔으면 아무것도 안 한다
    private func failPending() {
        isRequestingCoordinate = false
        guard let continuation = coordinateContinuation else { return }
        coordinateContinuation = nil
        continuation.resume(throwing: LocationError.unavailable)
    }

    /// 캐시 나이가 유효 시간 안인지 본다
    nonisolated static func isCacheFresh(age: TimeInterval, maxAge: Duration) -> Bool {
        guard age >= 0 else { return false }
        return age <= maxAge.timeInterval
    }

    static func mapped(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        case .denied, .restricted:
            return .denied
        @unknown default:
            // 새 상태가 생기면 안전한 쪽으로 붙인다. 안내 화면이 뜨지 잘못 이동하지 않는다
            return .denied
        }
    }
}

extension SystemLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard let continuation = authorizationContinuation else { return }
            // 인자로 온 manager 를 여기로 넘기면 Sendable 이 아니라 컴파일이 막는다.
            // 같은 객체인 self.manager 를 읽는다
            let status = Self.mapped(self.manager.authorizationStatus)
            // 창이 뜬 직후에도 한 번 불린다. 아직 미결정이면 사용자가 안 고른 것이다
            guard status != .notDetermined else { return }
            authorizationContinuation = nil
            continuation.resume(returning: status)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        MainActor.assumeIsolated {
            isRequestingCoordinate = false
            guard let continuation = coordinateContinuation else { return }
            coordinateContinuation = nil
            guard let location = locations.last else {
                continuation.resume(throwing: LocationError.unavailable)
                return
            }
            continuation.resume(
                returning: Coordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude
                )
            )
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        MainActor.assumeIsolated {
            isRequestingCoordinate = false
            guard let continuation = coordinateContinuation else { return }
            coordinateContinuation = nil
            let mapped: LocationError = (error as? CLError)?.code == .denied ? .denied : .unavailable
            continuation.resume(throwing: mapped)
        }
    }
}

private extension Duration {
    var timeInterval: TimeInterval {
        let components = self.components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
