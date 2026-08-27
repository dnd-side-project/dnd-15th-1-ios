import Foundation

/// 좌표 1회 조회가 실패하는 까닭.
///
/// 화면은 둘을 안 가리고 같은 토스트를 띄운다. 나눠 둔 것은 로그를 읽을 때를 위해서다
public enum LocationError: Error, Equatable, Sendable {
    /// 권한이 없어 좌표를 못 얻는다
    case denied
    /// 기기가 좌표를 못 준다. 시간 초과를 포함한다
    case unavailable
}
