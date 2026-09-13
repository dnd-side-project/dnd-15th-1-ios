//
//  PlaceDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation
import SharedUtils

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

    private static let maxPage = 44

    static func toSearchPage(_ dto: PlaceSearchResponseDTO, page: Int) -> PlacePage {
        PlacePage(
            items: dto.places.map(toPlace),
            // 명세의 page 최대값이 44 다. 45 를 요청하면 서버가 400 을 준다.
            // 여기서 끊어 화면이 서버 제약을 몰라도 되게 한다
            hasNext: dto.hasNext && page < maxPage
        )
    }

    static func toDomain(_ dto: PlaceDetailResponseDTO) -> PlaceDetail {
        PlaceDetail(
            place: toPlace(dto),
            savedByMe: dto.savedByMe,
            savedMemberCount: dto.savedMemberCount,
            ownership: dto.ownershipStatus.flatMap { PlaceOwnership(rawValue: $0.lowercased()) },
            phone: dto.phone,
            kakaoPlaceURL: dto.kakaoPlaceUrl.flatMap(URL.init(string:))
        )
    }

    // placeId 는 미저장 장소라 null → kakaoPlaceId 를 식별자로 쓴다.
    // 둘 다 없어도 매핑마다 달라지지 않게 좌표·이름으로 결정적 식별자를 만든다
    private static func toPlace(_ dto: PlaceSearchItemDTO) -> Place {
        Place(
            id: dto.placeId.map(String.init) ?? dto.kakaoPlaceId ?? "\(dto.name)|\(dto.latitude)|\(dto.longitude)",
            kakaoPlaceID: dto.kakaoPlaceId,
            name: dto.name,
            category: category(code: dto.categoryCode, name: dto.categoryName),
            address: dto.address,
            roadAddress: dto.roadAddress ?? "",
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            bookmarkCount: 0,
            thumbnailURLs: dto.imageUrls.compactMap(URL.init(string:))
        )
    }

    // 상세 응답은 kakaoPlaceId 가 항상 있어 합성 폴백이 필요 없다
    private static func toPlace(_ dto: PlaceDetailResponseDTO) -> Place {
        Place(
            id: dto.placeId.map(String.init) ?? dto.kakaoPlaceId,
            kakaoPlaceID: dto.kakaoPlaceId,
            name: dto.name,
            category: category(code: dto.categoryCode, name: dto.categoryName),
            address: dto.address,
            roadAddress: dto.roadAddress ?? "",
            // 명세는 nullable 이지만 실측 120/120 값이 있었다. 없는 응답은 0,0 으로 둔다
            coordinate: Coordinate(
                latitude: dto.latitude ?? 0,
                longitude: dto.longitude ?? 0
            ),
            bookmarkCount: dto.savedMemberCount,
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
            roadAddress: dto.roadAddress ?? "",
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

    // 상세·검색 응답에는 ASCII categoryCode 가 실려 온다. 그것이 있으면 먼저 본다.
    // 저장 목록·저장 응답에는 없어 한글 categoryName 으로 계속 매핑한다
    private static func category(code: String?, name: String) -> PlaceCategory {
        switch code {
        case "RESTAURANT": return .food
        case "CAFE": return .cafe
        case "ENTERTAINMENT": return .activity
        case "SHOPPING": return .shopping
        case "CONVENIENCE": return .convenience
        case "TOURISM": return .tourism
        case "ACCOMMODATION": return .accommodation
        default: return category(name)
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
