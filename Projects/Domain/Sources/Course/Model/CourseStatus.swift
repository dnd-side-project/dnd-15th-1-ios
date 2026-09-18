import Foundation

/// 코스 상태. `draft` 는 쓰다 만 코스, `confirmed` 는 확정된 데이트다.
/// 홈의 다가오는·지난 데이트는 확정된 코스만 본다. 서버 문자열 변환은 Data 가 맡는다
public enum CourseStatus: Equatable, Sendable {
    case draft
    case confirmed
}
