import Foundation
import ThirdParty

@DependencyClient
public struct PostDetailContentClient: Sendable {
    /// GET /api/v1/contents/{id}
    public var contentDetail: @Sendable (_ id: String) async throws -> PostDetailContent
}

extension PostDetailContentClient: TestDependencyKey {
    public static let testValue = PostDetailContentClient()
    public static let previewValue = PostDetailContentClient.mock
}

public extension DependencyValues {
    var postDetailContentClient: PostDetailContentClient {
        get { self[PostDetailContentClient.self] }
        set { self[PostDetailContentClient.self] = newValue }
    }
}
