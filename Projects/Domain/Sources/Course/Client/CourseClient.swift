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
    /// 코스에 담을 수 있는 저장 장소. 장소 번호가 늘 있다
    public var coursePlaces: @Sendable () async throws -> [SavedPlace]

    /// 커플이 저장한 장소를 검색어로 찾는다. 장소명·별칭·주소에 부분 일치한다.
    /// 검색어가 nil 이거나 비면 거르지 않는다. 한 페이지 10건이고 page 는 0 부터 100 까지다.
    /// 커플이 없으면 notFound 다
    public var searchCoursePlaces: @Sendable (_ query: String?, _ page: Int) async throws -> Page<SavedPlace>

    /// GET /api/v1/date-courses/{dateCourseId}
    public var course: @Sendable (_ id: String) async throws -> DateCourse

    /// GET /api/v1/date-courses/current
    public var currentCourse: @Sendable () async throws -> DateCourseSummary?

    /// GET /api/v1/home/past-dates
    /// 가장 최근 지난 데이트부터 size 개다
    public var latestPastCourses: @Sendable (_ size: Int) async throws -> [DateCourseSummary]

    /// GET /api/v1/date-courses/past
    /// totalCount 는 전체 데이트 횟수다
    public var pastCourses: @Sendable (_ page: Int, _ size: Int) async throws -> PastDateCoursePage

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
