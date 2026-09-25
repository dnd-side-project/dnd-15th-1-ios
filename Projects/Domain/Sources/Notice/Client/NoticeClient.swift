import Foundation
import ThirdParty

@DependencyClient
public struct NoticeClient: Sendable {
    /// 페이지 크기는 조립 코드가 고정한다
    public var notices: @Sendable (_ page: Int) async throws -> NoticePage
}

extension NoticeClient: TestDependencyKey {
    public static let testValue = NoticeClient()
    public static let previewValue = NoticeClient.mock
}

public extension DependencyValues {
    var noticeClient: NoticeClient {
        get { self[NoticeClient.self] }
        set { self[NoticeClient.self] = newValue }
    }
}
