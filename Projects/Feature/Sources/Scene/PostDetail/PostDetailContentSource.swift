//
//  PostDetailContentSource.swift
//  Dulpick
//

import ThirdParty

/// 게시글 상세 값을 가져오는 자리. 지금은 고정값만 돌려준다.
/// 탐색 계층을 DND-67 이 만들면 이 몸통만 Domain `ExploreClient` 호출로 바꾼다
@DependencyClient
public struct PostDetailContentSource: Sendable {
    public var load: @Sendable (_ id: String) async throws -> PostDetailContent
}

extension PostDetailContentSource: DependencyKey {
    public static let liveValue = PostDetailContentSource(load: { id in .fixture(id: id) })
    public static let previewValue = liveValue
    public static let testValue = PostDetailContentSource()
}

public extension DependencyValues {
    var postDetailContentSource: PostDetailContentSource {
        get { self[PostDetailContentSource.self] }
        set { self[PostDetailContentSource.self] = newValue }
    }
}
