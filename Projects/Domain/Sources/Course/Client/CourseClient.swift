import Foundation
import ThirdParty

@DependencyClient
public struct CourseClient: Sendable {
    /// POST /api/v1/date-courses
    /// 데이트명·날짜·시간만 보낸다. 장소는 안 보낸다. 응답은 `DRAFT` 코스다
    public var createCourse: @Sendable (
        _ title: String,
        _ date: DateComponents,
        _ time: DateComponents
    ) async throws -> DateCourse

    /// GET /api/v1/date-courses/places
    public var coursePlaces: @Sendable () async throws -> [CoursePlaceCandidate]

    /// GET /api/v1/date-courses/{dateCourseId}
    /// 부르는 화면이 아직 없다. DND-52 데이트 코스 결과 화면이 붙인다
    public var course: @Sendable (_ id: String) async throws -> DateCourse

    /// PUT /api/v1/date-courses/{dateCourseId}
    /// 부르는 화면이 아직 없다. DND-52 에서 `saveType`(`TEMPORARY`/`CONFIRM`) 과
    /// `version` 을 더한다. 소비자 없이 미리 만들면 또 틀린다
    public var updateCourse: @Sendable (
        _ id: String,
        _ title: String,
        _ scheduledAt: Date,
        _ placeIDs: [String]
    ) async throws -> DateCourse

    /// 시안 `{상대닉네임}에게 코스 알리기`. 명세에 해당 엔드포인트가 없다
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
