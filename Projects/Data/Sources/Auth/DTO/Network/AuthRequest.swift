import Foundation

// MARK: - Reissue

struct AuthReissueRequestDTO: Encodable, Equatable, Sendable {
    let refreshToken: String
}

// MARK: - Logout

struct AuthLogoutRequestDTO: Encodable, Equatable, Sendable {
    let refreshToken: String
}
