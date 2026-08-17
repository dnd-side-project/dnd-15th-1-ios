import Foundation

/// 커플 연결 상태 조회(`GET /couples/me`) 결과. connected 로 연결 여부를 직접 판단한다.
public struct CoupleStatus: Equatable, Sendable {
    public let connected: Bool
    public let me: CoupleMember
    public let partner: CoupleMember?
    public let daysTogether: Int?

    public init(
        connected: Bool,
        me: CoupleMember,
        partner: CoupleMember?,
        daysTogether: Int?
    ) {
        self.connected = connected
        self.me = me
        self.partner = partner
        self.daysTogether = daysTogether
    }
}
