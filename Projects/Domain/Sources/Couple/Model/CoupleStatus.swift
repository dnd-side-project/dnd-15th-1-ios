import Foundation

/// 커플 연결 상태(`GET /couples/me`). 연결됐을 때만 내 정보·상대·함께한 날이 있다
public enum CoupleStatus: Equatable, Sendable {
    /// 함께한 날은 서버가 null 을 줄 수 있다
    case connected(me: CoupleMember, partner: CoupleMember, daysTogether: Int?)
    case notConnected
}
