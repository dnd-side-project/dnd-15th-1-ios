import Foundation

// MARK: - Nonce

struct AuthNonceDTO: Decodable, Equatable, Sendable {
    let nonce: String
    let expiresAt: String
}

// MARK: - Token

struct AuthTokenDTO: Decodable, Equatable, Sendable {
    let tokenType: String
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
}

// MARK: - Social Login

struct SocialLoginResponseDTO: Decodable, Equatable, Sendable {
    let memberId: Int
    let newMember: Bool
    /// 서버가 필드를 생략해도 로그인 자체가 `decodingFailed` 로 죽지 않도록 optional 로 받는다.
    let onboardingCompleted: Bool?
    let token: AuthTokenDTO
}
