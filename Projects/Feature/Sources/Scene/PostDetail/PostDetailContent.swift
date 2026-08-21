//
//  PostDetailContent.swift
//  Dulpick
//

import Domain
import Foundation

/// 게시글 상세가 그리는 값.
/// 탐색 계층은 DND-67 이 가져간다. 그 전까지 Domain 을 안 거치고 여기 고정값으로 돈다
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

    public init(
        id: String,
        name: String,
        category: PlaceCategory,
        isSaved: Bool
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.isSaved = isSaved
    }
}

public extension PostDetailContent {
    /// 본문이 3줄을 넘고 장소 5개를 갖는다. 저장 2 · 미저장 3
    static func fixture(id: String = "1") -> PostDetailContent {
        PostDetailContent(
            id: id,
            title: "새벽까지 함께할 수 있는 데이트 성지 한강뷰 감성카페",
            caption: """
            한강이 통째로 보이는 창가 자리가 진짜 명당이에요. \
            평일 저녁에는 사람이 적어서 조용히 이야기 나누기 좋고, \
            주말에는 웨이팅이 삼십 분 정도 있으니 미리 가는 걸 권해요. \
            디저트는 바스크 치즈케이크가 제일 인기가 많고, \
            음료는 시그니처 라떼를 시키면 실패가 없습니다. \
            근처에 산책하기 좋은 길이 이어져 있어서 식사 뒤 코스로 묶기도 좋아요.
            """,
            canonicalURL: URL(string: "https://www.instagram.com/reel/example/"),
            places: [
                PostDetailPlace(id: "101", name: "한강뷰 감성카페", category: .cafe, isSaved: true),
                PostDetailPlace(id: "102", name: "성수동 브런치집", category: .food, isSaved: false),
                PostDetailPlace(id: "103", name: "야경 좋은 전망대", category: .tourism, isSaved: true),
                PostDetailPlace(id: "104", name: "소품샵 골목", category: .shopping, isSaved: false),
                PostDetailPlace(id: "105", name: "심야 보드게임 카페", category: .activity, isSaved: false),
            ]
        )
    }
}
