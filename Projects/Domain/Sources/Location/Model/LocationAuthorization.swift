import Foundation

/// 위치 권한 상태. `CLAuthorizationStatus` 를 화면이 갈라야 하는 세 갈래로 줄인 것이다.
///
/// `Domain` 은 `CoreLocation` 을 모른다. 매핑은 `Data` 가 한다
public enum LocationAuthorization: Equatable, Sendable {
    /// 아직 물어본 적이 없다. 버튼을 누르면 시스템 권한 요청을 띄운다
    case notDetermined
    /// 사용 중 허용 또는 항상 허용
    case authorized
    /// 거부 또는 기기 정책으로 막힘. 둘의 화면 처리가 같아 한 갈래로 합쳤다
    case denied
}
