import Foundation
import ThirdParty

@DependencyClient
public struct CourseClient: Sendable {
    /// POST /api/v1/date-courses
    /// 데이트명·날짜·시간만 보낸다. 장소는 안 보낸다. 응답은 `DRAFT` 코스다
    public var createCourse: @Sendable (
        _ title: String,
        _ date: DateComponents,
        _ time: DateComponents?
    ) async throws -> DateCourse

    /// GET /api/v1/date-courses/places
    public var coursePlaces: @Sendable () async throws -> [CoursePlaceCandidate]

    /// GET /api/v1/date-courses/{dateCourseId}
    public var course: @Sendable (_ id: String) async throws -> DateCourse

    /// GET /api/v1/date-courses/current
    public var currentCourse: @Sendable () async throws -> DateCourseSummary?

    /// PUT /api/v1/date-courses/{dateCourseId}
    /// 확정 저장이다
    public var updateCourse: @Sendable (
        _ id: String,
        _ content: DateCourseContent,
        _ version: Int
    ) async throws -> DateCourse

    /// POST /api/v1/date-courses/{dateCourseId}/notify-partner
    public var notifyPartner: @Sendable (_ id: String) async throws -> Void
}

extension CourseClient: TestDependencyKey {
    public static let testValue = CourseClient()
    public static let previewValue = CourseClient.mock
}

public extension DependencyValues {
    var courseClient: CourseClient {
        get { self[CourseClient.self] }
        set { self[CourseClient.self] = newValue }
    }
}
