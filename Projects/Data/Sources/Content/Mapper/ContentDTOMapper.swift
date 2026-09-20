//
//  ContentDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation
import SharedUtils

enum ContentDTOMapper {
    /// 정렬 기준을 서버 쿼리 값으로 바꾼다
    static func toQuery(_ sort: ContentSort) -> String {
        switch sort {
        case .popular: return "POPULAR"
        case .preference: return "PREFERENCE"
        }
    }

    static func toFeed(_ dto: ContentPageResponseDTO) -> ContentFeed {
        ContentFeed(page: toDomain(dto), popularTags: dto.popularTags ?? [])
    }

    static func toDomain(_ dto: ContentPageResponseDTO) -> ContentPage {
        ContentPage(
            items: dto.contents.map(toContent),
            hasNext: dto.hasNext
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
            places: (dto.places ?? []).map(toContentPlace)
        )
    }

    /// 게시글 속 장소. 게시글 응답은 장소 번호를 늘 준다
    private static func toContentPlace(_ dto: ContentDetailPlaceResponseDTO) -> ContentPlace {
        ContentPlace(
            place: Place(
                placeID: String(dto.placeId),
                kakaoPlaceID: dto.kakaoPlaceId,
                name: dto.name,
                category: PlaceDTOMapper.category(code: nil, name: dto.categoryName),
                address: dto.address,
                roadAddress: PlaceDTOMapper.roadAddress(dto.roadAddress),
                coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
                // 게시글 응답에는 저장 수가 없다
                bookmarkCount: nil,
                // 대표 사진을 버리지 않는다. 모든 장소 매퍼가 같은 규칙이다
                thumbnailURLs: PlaceDTOMapper.photoURLs(
                    thumbnailURL: dto.thumbnailUrl,
                    imageURLs: dto.imageUrls ?? []
                )
            ),
            isSaved: dto.savedByMe
        )
    }
}
