import Foundation

public enum PushError: Error, Equatable, Sendable {
    /// 연결 실패·타임아웃
    case network
    /// 401. 세션이 없거나 만료됐다
    case unauthorized
    /// 400. 플랫폼·공급자·등록 토큰이 누락됐거나 허용되지 않은 값이다
    case invalidRequest
    /// 409. 푸시 디바이스 등록 상태가 충돌했다
    case registrationConflict
    /// 503. 외부 연동 실패로 등록할 수 없다
    case providerUnavailable
    case unknown
}
