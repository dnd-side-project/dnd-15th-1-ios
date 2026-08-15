import Foundation
import ThirdParty

/// 서버 명세가 없다. 시안 c01~c10 에서 역산한 계약이다.
/// API 가 나오면 시그니처가 바뀔 수 있다.
@DependencyClient
public struct CourseClient: Sendable {
    /// 장소를 고른 순서대로 코스를 만든다. 구간 값은 서버가 채워 보낸다
    public var createCourse: @Sendable (
        _ scheduledAt: Date,
        _ placeIDs: [String]
    ) async throws -> DateCourse

    public var course: @Sendable (_ id: String) async throws -> DateCourse

    /// 제목·시각·장소 순서를 통째로 덮어쓴다. 구간 값은 다시 계산돼 온다
    public var updateCourse: @Sendable (
        _ id: String,
        _ title: String,
        _ scheduledAt: Date,
        _ placeIDs: [String]
    ) async throws -> DateCourse

    /// 시안 `{상대닉네임}에게 코스 알리기`
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
