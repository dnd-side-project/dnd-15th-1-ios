import Foundation

/// 서버 `status`. `DRAFT` 는 쓰다 만 코스, `CONFIRMED` 는 확정된 데이트다.
/// 홈의 다가오는·지난 데이트는 `CONFIRMED` 만 본다
public enum CourseStatus: String, Equatable, Sendable {
    case draft
    case confirmed
}
