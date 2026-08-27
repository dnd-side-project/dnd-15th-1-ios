import Foundation

public enum CoupleError: Error, Equatable, Sendable {
    /// 초대 코드가 없거나 유효하지 않음
    case invalidInviteCode

    /// 이미 커플 연결 상태
    case alreadyConnected

    /// 요청 횟수 제한 초과
    case rateLimited

    /// 네트워크 단절/전송 실패
    case network

    /// 세션 만료, 인증 실패(401 계열) 등 인가 불가
    case unauthorized

    /// 분류되지 않은 실패
    case unknown
}
