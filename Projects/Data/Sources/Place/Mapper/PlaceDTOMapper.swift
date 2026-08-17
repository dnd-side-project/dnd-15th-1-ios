//
//  PlaceDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

enum PlaceDTOMapper {
    static func toDomain(_ dto: SavedPlaceResponseDTO) -> SavedPlace {
        SavedPlace(
            place: toPlace(dto),
            ownership: ownership(dto.ownershipStatus),
            alias: dto.alias,
            memo: nil,
            savedAt: parseDate(dto.savedAt)
        )
    }

    private static func toPlace(_ dto: SavedPlaceResponseDTO) -> Place {
        Place(
            id: String(dto.placeId),
            kakaoPlaceID: nil,
            name: dto.name,
            category: category(dto.categoryName),
            address: dto.address,
            roadAddress: dto.roadAddress,
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            bookmarkCount: 0,
            thumbnailURLs: dto.imageUrls.compactMap(URL.init(string:))
        )
    }

    private static func ownership(_ raw: String) -> PlaceOwnership {
        PlaceOwnership(rawValue: raw.lowercased()) ?? .mine
    }

    // 서버 categoryName(한글) 을 카테고리로 매핑
    private static func category(_ name: String) -> PlaceCategory {
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

    // "2026-08-17T01:27:55.129814" 처럼 타임존 없는 형식이라 초 단위까지만 파싱
    private static func parseDate(_ raw: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: String(raw.prefix(19))) ?? Date()
    }
}
