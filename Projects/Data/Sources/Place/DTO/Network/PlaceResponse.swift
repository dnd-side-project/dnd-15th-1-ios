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
    /// 검색 응답에는 ASCII 코드가 실려 온다. 한글 이름보다 이쪽을 먼저 본다
    let categoryCode: String?
    let categoryName: String
    let thumbnailUrl: String?
    let imageUrls: [String]
}

/// 상세 조회 공용 DTO.
/// GET /api/v1/places/{placeId} 와 GET /api/v1/places/kakao/{kakaoPlaceId} 가 같은 스키마다.
/// 좌표는 명세가 nullable 로 적어 옵셔널로 둔다. 실측 120건은 모두 값이 있었다
struct PlaceDetailResponseDTO: Decodable, Sendable {
    let placeId: Int?
    let kakaoPlaceId: String
    let name: String
    let address: String
    let roadAddress: String?
    let latitude: Double?
    let longitude: Double?
    let category: String?
    /// 명세는 required 지만 빠져도 상세가 죽지 않게 옵셔널로 둔다
    let categoryCode: String?
    let categoryName: String
    let phone: String?
    let kakaoPlaceUrl: String?
    let savedByMe: Bool
    let ownershipStatus: String?
    let thumbnailUrl: String?
    let imageUrls: [String]
    let savedMemberCount: Int
}
