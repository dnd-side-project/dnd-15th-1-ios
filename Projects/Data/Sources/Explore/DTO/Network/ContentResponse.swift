//
//  ContentResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

// 그리드가 쓰는 필드만 선언. author/engagement/places 등 나머지 키는 디코딩에서 무시됨
struct ContentPageResponseDTO: Decodable, Sendable {
    let contents: [ContentResponseDTO]
    let hasNext: Bool
    let popularTags: [String]?
}

struct ContentResponseDTO: Decodable, Sendable {
    let contentId: Int
    let title: String
    let thumbnailUrl: String?
    let placeCount: Int
}

// 상세가 쓰는 필드만 선언. sourceType/author/engagement/publishedOn/thumbnailUrl 등은 무시됨
struct ContentDetailResponseDTO: Decodable, Sendable {
    let contentId: Int
    let title: String?
    let caption: String?
    let canonicalUrl: String?
    let places: [ContentDetailPlaceResponseDTO]?
}

// 인스타 추출(ImportPlace)과 동일한 형태. 쓰는 필드만 선언
struct ContentDetailPlaceResponseDTO: Decodable, Sendable {
    let placeId: Int
    let kakaoPlaceId: String?
    let name: String
    // 주소·도로명은 없는 장소가 있어 옵셔널
    let address: String?
    let roadAddress: String?
    let categoryName: String
    let latitude: Double
    let longitude: Double
    let savedByMe: Bool
    let thumbnailUrl: String?
    // 이미지가 없는 장소도 있어 옵셔널
    let imageUrls: [String]?
}
