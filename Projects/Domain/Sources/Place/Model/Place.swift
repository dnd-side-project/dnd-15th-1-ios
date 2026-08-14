//
//  Place.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Foundation

public struct Place: Equatable, Identifiable, Sendable {
    public let id: String
    /// 저장 API(`POST /places`) 가 요구하는 Kakao 장소 ID.
    /// 검색 결과에는 실려 오고 저장 목록 응답에는 없다.
    public let kakaoPlaceID: String?
    public let name: String
    public let category: PlaceCategory
    /// 지번 주소
    public let address: String
    /// 도로명 주소
    public let roadAddress: String
    public let coordinate: Coordinate
    public let bookmarkCount: Int
    public let thumbnailURLs: [URL]

    public init(
        id: String,
        kakaoPlaceID: String?,
        name: String,
        category: PlaceCategory,
        address: String,
        roadAddress: String,
        coordinate: Coordinate,
        bookmarkCount: Int,
        thumbnailURLs: [URL]
    ) {
        self.id = id
        self.kakaoPlaceID = kakaoPlaceID
        self.name = name
        self.category = category
        self.address = address
        self.roadAddress = roadAddress
        self.coordinate = coordinate
        self.bookmarkCount = bookmarkCount
        self.thumbnailURLs = thumbnailURLs
    }
}
