//
//  ContentClient+Mock.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//
//  임시 mock 데이터
//

import Foundation
import SharedUtils
import ThirdParty

public extension ContentClient {
    static let mock = ContentClient(
        contents: { _, _, _ in
            ContentFeed(
                page: ContentPage(items: Content.mocks, hasNext: false),
                popularTags: ["성수", "강남", "을지로"]
            )
        },
        searchContents: { _, _, _, _ in
            ContentPage(items: Content.mocks, hasNext: false)
        },
        placeContents: { _, _, _ in
            ContentPage(items: Content.mocks, hasNext: false)
        },
        contentDetail: { id in .fixture(id: id) }
    )
}

public extension Content {
    static let mocks: [Content] = [
        Content(
            id: "1",
            title: "새벽까지 함께할 수 있는 데이트 성지 한강뷰 감성카페",
            thumbnailURLs: MockThumbnailURL.list(2, seed: 10),
            placeCount: 5
        ),
        Content(
            id: "2",
            title: "한강뷰 데이트 장소",
            thumbnailURLs: MockThumbnailURL.list(2, seed: 20),
            placeCount: 5
        ),
        Content(
            id: "3",
            title: "성수동 감성 카페 투어",
            thumbnailURLs: MockThumbnailURL.list(2, seed: 30),
            placeCount: 4
        ),
        Content(
            id: "4",
            title: "을지로 노포 맛집 코스",
            thumbnailURLs: MockThumbnailURL.list(2, seed: 40),
            placeCount: 6
        ),
    ]
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
                mockPlace(id: "101", name: "한강뷰 감성카페", category: .cafe, isSaved: true,
                          coordinate: Coordinate(latitude: 37.5299, longitude: 126.9648)),
                mockPlace(id: "102", name: "성수동 브런치집", category: .food, isSaved: false,
                          coordinate: Coordinate(latitude: 37.5445, longitude: 127.0559)),
                mockPlace(id: "103", name: "야경 좋은 전망대", category: .tourism, isSaved: true,
                          coordinate: Coordinate(latitude: 37.5512, longitude: 126.9882)),
                mockPlace(id: "104", name: "소품샵 골목", category: .shopping, isSaved: false,
                          coordinate: Coordinate(latitude: 37.5561, longitude: 126.9236)),
                mockPlace(id: "105", name: "심야 보드게임 카페", category: .activity, isSaved: false,
                          coordinate: Coordinate(latitude: 37.5637, longitude: 126.9860)),
            ]
        )
    }

    private static func mockPlace(
        id: String,
        name: String,
        category: PlaceCategory,
        isSaved: Bool,
        coordinate: Coordinate
    ) -> ContentPlace {
        ContentPlace(
            place: Place(
                placeID: id,
                kakaoPlaceID: nil,
                name: name,
                category: category,
                address: "",
                roadAddress: nil,
                coordinate: coordinate,
                bookmarkCount: nil,
                thumbnailURLs: []
            ),
            isSaved: isSaved
        )
    }
}
