import Foundation

/// 게시글 상세가 그리는 값.
public struct PostDetailContent: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    /// 본문 또는 캡션
    public let caption: String?
    /// 추적 파라미터를 없앤 인스타그램 링크
    public let canonicalURL: URL?
    public let places: [ContentPlace]

    public init(
        id: String,
        title: String?,
        caption: String?,
        canonicalURL: URL?,
        places: [ContentPlace]
    ) {
        self.id = id
        self.title = title
        self.caption = caption
        self.canonicalURL = canonicalURL
        self.places = places
    }
}
