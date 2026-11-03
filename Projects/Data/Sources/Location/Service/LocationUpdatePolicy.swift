import CoreLocation
import Foundation

/// 위치를 계속 받을 때 갱신을 켤지, 온 좌표를 쓸지 정한다. 위치 관리자 없이 시험한다
enum LocationUpdatePolicy {
    /// 「사용 중 허용」 이상이고 「정확한 위치」 가 켜져 있을 때만 켠다.
    /// 미결정이면 켜지 않는다. 켜면 iOS 가 권한 창을 띄울 수 있다
    static func canTrack(
        status: CLAuthorizationStatus,
        accuracy: CLAccuracyAuthorization
    ) -> Bool {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            return accuracy == .fullAccuracy
        case .notDetermined, .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// 오차가 음수면 좌표를 못 잡았다는 뜻이다. `maxAge` 보다 오래된 좌표도 버린다.
    /// 나이 판정은 1회 조회와 같은 기준을 쓴다
    static func accepts(
        horizontalAccuracy: CLLocationAccuracy,
        age: TimeInterval,
        maxAge: Duration
    ) -> Bool {
        guard horizontalAccuracy >= 0 else { return false }
        return SystemLocationProvider.isCacheFresh(age: age, maxAge: maxAge)
    }
}
