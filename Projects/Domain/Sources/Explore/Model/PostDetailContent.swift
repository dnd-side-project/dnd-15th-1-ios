import Foundation

/// 게시글 상세가 그리는 값.
public struct PostDetailContent: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String?
    /// 본문 또는 캡션
    public let caption: String?
    /// 추적 파라미터를 없앤 인스타그램 링크
    public let canonicalURL: URL?
    public let places: [PostDetailPlace]

    public init(
        id: String,
        title: String?,
        caption: String?,
        canonicalURL: URL?,
        places: [PostDetailPlace]
    ) {
        self.id = id
        self.title = title
        self.caption = caption
        self.canonicalURL = canonicalURL
        self.places = places
    }
}

public struct PostDetailPlace: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: PlaceCategory
    public let isSaved: Bool
    /// 지도 핀·카메라에 쓰는 좌표
    public let coordinate: Coordinate

    public init(
        id: String,
        name: String,
        category: PlaceCategory,
        isSaved: Bool,
        coordinate: Coordinate
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isSaved = isSaved
        self.coordinate = coordinate
    }
}
