//
//  ContentDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

enum ContentDTOMapper {
    static func toDomain(_ dto: ContentPageResponseDTO) -> ContentPage {
        ContentPage(
            items: dto.contents.map(toContent),
            hasNext: dto.hasNext,
            popularTags: dto.popularTags ?? []
        )
    }

    private static func toContent(_ dto: ContentResponseDTO) -> Content {
        Content(
            id: String(dto.contentId),
            title: dto.title,
            thumbnailURLs: [dto.thumbnailUrl].compactMap { $0 }.compactMap(URL.init(string:)),
            placeCount: dto.placeCount
        )
    }

    static func toDetail(_ dto: ContentDetailResponseDTO) -> PostDetailContent {
        PostDetailContent(
            id: String(dto.contentId),
            title: dto.title,
            caption: dto.caption,
            canonicalURL: dto.canonicalUrl.flatMap(URL.init(string:)),
            places: (dto.places ?? []).map(toDetailPlace)
        )
    }

    private static func toDetailPlace(_ dto: ContentDetailPlaceResponseDTO) -> PostDetailPlace {
        PostDetailPlace(
            id: String(dto.placeId),
            kakaoPlaceID: dto.kakaoPlaceId,
            name: dto.name,
            category: category(dto.categoryName),
            isSaved: dto.savedByMe,
            address: dto.address,
            roadAddress: dto.roadAddress,
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            imageURLs: (dto.imageUrls ?? []).compactMap(URL.init(string:))
        )
    }

    // 서버 categoryName(한글) 을 카테고리로 매핑. 값이 없으면 food 로 둔다
    private static func category(_ name: String?) -> PlaceCategory {
        switch name {
        case "카페": return .cafe
        case "관광": return .tourism
        case "놀거리": return .activity
        case "쇼핑": return .shopping
        case "숙박": return .accommodation
        case "편의", "생활 편의": return .convenience
        default: return .food
        }
    }
}
