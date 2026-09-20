import Foundation

/// 코스 요약. 예정 코스(`GET /api/v1/date-courses/current`)와 지난 데이트 두 목록이 준다.
/// 홈 배너·지도 버튼·지난 데이트 카드가 읽는다
public struct DateCourseSummary: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let scheduledAt: Date
    /// 지난 데이트 목록 응답에는 상태가 없어 nil 이다
    public let status: CourseStatus?
    public let totalPlaceCount: Int

    public init(
        id: String,
        title: String,
        scheduledAt: Date,
        status: CourseStatus?,
        totalPlaceCount: Int
    ) {
        self.id = id
        self.title = title
        self.scheduledAt = scheduledAt
        self.status = status
        self.totalPlaceCount = totalPlaceCount
    }
}
