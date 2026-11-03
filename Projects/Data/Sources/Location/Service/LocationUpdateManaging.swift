import CoreLocation

/// 위치를 계속 받을 때 쓰는 `CLLocationManager` 의 몫. 시험에서는 가짜로 바꾼다
@MainActor
protocol LocationUpdateManaging: AnyObject {
    var delegate: (any CLLocationManagerDelegate)? { get set }
    var desiredAccuracy: CLLocationAccuracy { get set }
    var distanceFilter: CLLocationDistance { get set }
    var authorizationStatus: CLAuthorizationStatus { get }
    var accuracyAuthorization: CLAccuracyAuthorization { get }
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension CLLocationManager: LocationUpdateManaging {}
