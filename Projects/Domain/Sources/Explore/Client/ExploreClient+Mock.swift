//
//  ExploreClient+Mock.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//
//  임시 mock 데이터
//

import Foundation
import ThirdParty

public extension ExploreClient {
    static let mock = ExploreClient(
        contents: { _, _, _ in
            ContentPage(items: Content.mocks, hasNext: false, popularTags: ["성수", "강남", "을지로"])
        },
        searchContents: { _, _, _, _ in
            ContentPage(items: Content.mocks, hasNext: false, popularTags: [])
        },
        searchPlaces: { _, _, _ in PlacePage(items: Place.mocks, hasNext: false) }
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
