import Foundation

public enum AuthError: Error, Equatable, Sendable {
    /// 사용자가 소셜 로그인/인증 플로우를 취소함
    case cancelled

    /// provider SDK 또는 앱 설정(키/capability)이 준비되지 않음
    case notConfigured

    /// nonce 발급, SDK 로그인, social-login 검증 등 로그인 흐름 실패
    case loginFailed

    /// 네트워크 단절/전송 실패
    case network

    /// 세션 만료, 인증 실패(401 계열) 등 인가 불가
    case unauthorized

    /// Keychain 등 로컬 세션 저장/조회 실패
    case storage

    /// 분류되지 않은 실패
    case unknown
}
