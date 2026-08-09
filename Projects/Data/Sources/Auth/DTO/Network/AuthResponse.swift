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
    let token: AuthTokenDTO
}
