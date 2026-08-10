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
        popularPosts: { Post.mocks },
        searchPosts: { _ in Post.mocks },
        searchPlaces: { _ in Place.mocks }
    )
}

public extension Post {
    static let mocks: [Post] = [
        Post(
            id: "1",
            title: "새벽까지 함께할 수 있는 데이트 성지 한강뷰 감성카페",
            thumbnailURLs: mockURLs(2, seed: 10),
            placeCount: 5
        ),
        Post(
            id: "2",
            title: "한강뷰 데이트 장소",
            thumbnailURLs: mockURLs(2, seed: 20),
            placeCount: 5
        ),
        Post(
            id: "3",
            title: "성수동 감성 카페 투어",
            thumbnailURLs: mockURLs(2, seed: 30),
            placeCount: 4
        ),
        Post(
            id: "4",
            title: "을지로 노포 맛집 코스",
            thumbnailURLs: mockURLs(2, seed: 40),
            placeCount: 6
        ),
    ]
}

public extension Place {
    static let mocks: [Place] = [
        Place(
            id: "1",
            name: "까치화방 카페 강남점",
            category: .cafe,
            bookmarkCount: 12,
            thumbnailURLs: []
        ),
        Place(
            id: "2",
            name: "까치화방 카페 성수역",
            category: .cafe,
            bookmarkCount: 12,
            thumbnailURLs: mockURLs(4, seed: 50)
        ),
    ]
}

private func mockURLs(_ count: Int, seed: Int) -> [URL] {
    (0..<count)
        .map { "https://picsum.photos/id/\(seed + $0)/300/300" }
        .compactMap(URL.init(string:))
}
