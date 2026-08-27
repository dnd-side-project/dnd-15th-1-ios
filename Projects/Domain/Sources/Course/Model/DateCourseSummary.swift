import Foundation

/// 예정 데이트 요약. `GET /api/v1/home` · `GET /api/v1/date-courses/current` 가 주고 홈 배너와 지도 버튼이 읽는다.
public struct DateCourseSummary: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let scheduledAt: Date
    public let status: CourseStatus
    public let version: Int
    public let totalPlaceCount: Int

    public init(
        id: String,
        title: String,
        scheduledAt: Date,
        status: CourseStatus,
        version: Int,
        totalPlaceCount: Int
    ) {
        self.id = id
        self.title = title
        self.scheduledAt = scheduledAt
        self.status = status
        self.version = version
        self.totalPlaceCount = totalPlaceCount
    }
}
