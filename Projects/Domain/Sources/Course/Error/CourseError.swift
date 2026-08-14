import Foundation

public enum CourseError: Error, Equatable, Sendable {
    /// 네트워크 단절/전송 실패
    case network

    /// 세션 만료, 인증 실패(401 계열) 등 인가 불가
    case unauthorized

    /// `course(id:)` 로 조회한 코스가 없음. 삭제됐거나 존재하지 않는 id
    case notFound

    /// `createCourse` / `updateCourse` 에 넘긴 장소 수가 코스 최소 기준에 못 미침.
    /// 최소 몇 곳인지는 서버 명세가 없어 미확정이다. 명세가 나오면 확정된다
    case tooFewPlaces

    /// `notifyPartner(id:)` 호출 시점에 커플 연결이 없어 알릴 상대가 없음.
    /// 코스를 만든 시점이 아니라 알리기를 누른 시점의 연결 상태를 말한다
    case partnerNotConnected

    /// 분류되지 않은 실패
    case unknown
}
