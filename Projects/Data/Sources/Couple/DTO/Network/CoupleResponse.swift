import Foundation

// MARK: - Connection Code

struct ConnectionCodeResponseDTO: Decodable, Equatable, Sendable {
    let code: String
    let shareUrl: String?
}

// MARK: - Couple Member Profile

struct CoupleMemberProfileResponseDTO: Decodable, Equatable, Sendable {
    let nickname: String
    let profileIcon: Int
}

// MARK: - Couple Connection Status

struct CoupleConnectionStatusResponseDTO: Decodable, Equatable, Sendable {
    let connected: Bool
    let me: CoupleMemberProfileResponseDTO?
    let partner: CoupleMemberProfileResponseDTO?
    // Domain 이 쓰지 않는 값이라 Date 로 디코딩하지 않는다. 서버가 null 을 주는 필드다.
    let connectedAt: String?
    let daysTogether: Int?
}
