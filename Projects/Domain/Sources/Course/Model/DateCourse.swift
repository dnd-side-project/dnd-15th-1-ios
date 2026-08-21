import Foundation

public struct DateCourse: Equatable, Identifiable, Sendable {
    public let id: String
    /// 시안 `26.08.05 데이트`
    public let title: String
    public let scheduledAt: Date
    public let status: CourseStatus
    /// 낙관적 락 번호. 클라이언트가 세지 않고 서버 응답 값을 그대로 들고 다닌다
    public let version: Int
    /// 방문 순서대로. 번호 배지가 이 순서를 따른다
    public let stops: [CourseStop]
    /// 서버가 계산해 보낸 구간 값. 항상 `stops.count - 1` 개
    public let legs: [CourseLeg]

    public init(
        id: String,
        title: String,
        scheduledAt: Date,
        status: CourseStatus,
        version: Int,
        stops: [CourseStop],
        legs: [CourseLeg]
    ) {
        self.id = id
        self.title = title
        self.scheduledAt = scheduledAt
        self.status = status
        self.version = version
        self.stops = stops
        self.legs = legs
    }
}

public extension DateCourse {
    var totalWalkingMinutes: Int { legs.reduce(0) { $0 + $1.walkingMinutes } }
    var totalDistanceMeters: Int { legs.reduce(0) { $0 + $1.distanceMeters } }
}
