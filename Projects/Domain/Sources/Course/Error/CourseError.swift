import Foundation

public enum CourseError: Error, Equatable, Sendable {
    /// 네트워크 단절/전송 실패
    case network

    /// 세션 만료, 인증 실패(401 계열) 등 인가 불가
    case unauthorized

    /// 대상 코스를 서버가 찾지 못함
    case notFound

    /// 코스를 만들기에 장소 수가 부족함.
    /// 최소 몇 곳인지는 서버 명세가 없어 미확정이다
    case tooFewPlaces

    /// 코스를 알릴 커플 상대가 연결돼 있지 않음.
    /// 코스를 만든 시점이 아니라 알림을 보내는 시점의 연결 상태다
    case partnerNotConnected

    /// 분류되지 않은 실패
    case unknown
}
