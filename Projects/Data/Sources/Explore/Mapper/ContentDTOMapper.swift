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
}
