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

    static func toSearchPage(_ dto: PlaceSearchResponseDTO) -> PlacePage {
        PlacePage(
            items: dto.places.map(toPlace),
            hasNext: dto.hasNext
        )
    }

    // placeId 는 미저장 장소라 null → kakaoPlaceId 를 식별자로 쓴다.
    // 둘 다 없어도 매핑마다 달라지지 않게 좌표·이름으로 결정적 식별자를 만든다
    private static func toPlace(_ dto: PlaceSearchItemDTO) -> Place {
        Place(
            id: dto.placeId.map(String.init) ?? dto.kakaoPlaceId ?? "\(dto.name)|\(dto.latitude)|\(dto.longitude)",
            kakaoPlaceID: dto.kakaoPlaceId,
            name: dto.name,
            category: category(dto.categoryName),
            address: dto.address,
            roadAddress: dto.roadAddress,
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            bookmarkCount: 0,
            thumbnailURLs: dto.imageUrls.compactMap(URL.init(string:))
        )
    }

    private static func toPlace(_ dto: SavedPlaceResponseDTO) -> Place {
        Place(
            id: String(dto.placeId),
            kakaoPlaceID: dto.kakaoPlaceId,
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

    // "2026-08-17T01:27:55.129814" 처럼 타임존 없는 형식이라 초 단위까지만 파싱.
    // 실패 시 현재 시각으로 위조하지 않고 nil 로 둔다
    private static func parseDate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: String(raw.prefix(19)))
    }
}
