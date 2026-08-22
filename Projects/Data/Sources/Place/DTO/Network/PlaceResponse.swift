//
//  PlaceResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

struct SavedPlaceResponseDTO: Decodable, Sendable {
    let memberId: Int
    let placeId: Int
    let kakaoPlaceId: String?
    let name: String
    let address: String
    // 도로명이 없는 장소가 있어 옵셔널
    let roadAddress: String?
    let latitude: Double
    let longitude: Double
    let category: String
    let categoryName: String
    let ownershipStatus: String
    let alias: String?
    let savedAt: String
    let thumbnailUrl: String?
    let imageUrls: [String]
}

// 장소 검색 결과. 그리드가 쓰는 필드만 선언한다. placeId 는 미저장 장소라 null 로 온다
struct PlaceSearchResponseDTO: Decodable, Sendable {
    let places: [PlaceSearchItemDTO]
    let hasNext: Bool
}

struct PlaceSearchItemDTO: Decodable, Sendable {
    let placeId: Int?
    let kakaoPlaceId: String?
    let name: String
    let address: String
    let roadAddress: String?
    let latitude: Double
    let longitude: Double
    let categoryName: String
    let thumbnailUrl: String?
    let imageUrls: [String]
}
