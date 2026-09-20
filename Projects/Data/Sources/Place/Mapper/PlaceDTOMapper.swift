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
            // 모르는 저장 관계는 내가 저장한 것으로 둔다
            ownership: ownership(dto.ownershipStatus) ?? .mine,
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
            isSaved: dto.savedByMe,
            ownership: dto.ownershipStatus.flatMap { ownership($0) },
            phone: dto.phone,
            kakaoPlaceURL: dto.kakaoPlaceUrl.flatMap(URL.init(string:))
        )
    }

    // 미저장 장소는 placeId 가 null 로 온다. id 는 Place 가 카카오 번호·이름·좌표로 계산한다
    private static func toPlace(_ dto: PlaceSearchItemDTO) -> Place {
        Place(
            placeID: dto.placeId.map(String.init),
            kakaoPlaceID: dto.kakaoPlaceId,
            name: dto.name,
            category: category(code: dto.categoryCode, name: dto.categoryName),
            address: dto.address,
            roadAddress: roadAddress(dto.roadAddress),
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            // 검색 응답에는 저장 수가 없다
            bookmarkCount: nil,
            thumbnailURLs: photoURLs(thumbnailURL: dto.thumbnailUrl, imageURLs: dto.imageUrls)
        )
    }

    // 서버가 모르는 카카오 장소는 placeId 가 null 이다
    private static func toPlace(_ dto: PlaceDetailResponseDTO) -> Place {
        Place(
            placeID: dto.placeId.map(String.init),
            kakaoPlaceID: dto.kakaoPlaceId,
            name: dto.name,
            category: category(code: dto.categoryCode, name: dto.categoryName),
            address: dto.address,
            roadAddress: roadAddress(dto.roadAddress),
            // 명세는 nullable 이지만 실측 120/120 값이 있었다. 없는 응답은 0,0 으로 둔다
            coordinate: Coordinate(
                latitude: dto.latitude ?? 0,
                longitude: dto.longitude ?? 0
            ),
            bookmarkCount: dto.savedMemberCount,
            thumbnailURLs: photoURLs(thumbnailURL: dto.thumbnailUrl, imageURLs: dto.imageUrls)
        )
    }

    private static func toPlace(_ dto: SavedPlaceResponseDTO) -> Place {
        Place(
            placeID: String(dto.placeId),
            kakaoPlaceID: dto.kakaoPlaceId,
            name: dto.name,
            // 저장 목록·저장 응답에는 ASCII 코드가 없어 한글 이름으로 읽는다
            category: category(code: nil, name: dto.categoryName),
            address: dto.address,
            roadAddress: roadAddress(dto.roadAddress),
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            bookmarkCount: dto.savedMemberCount,
            thumbnailURLs: photoURLs(thumbnailURL: dto.thumbnailUrl, imageURLs: dto.imageUrls)
        )
    }

    // MARK: - 장소 응답 공통 변환

    /// 서버 카테고리를 앱 카테고리로 바꾼다. 상세·검색 응답의 ASCII 코드가 있으면 먼저 보고,
    /// 없거나 모르는 코드면 한글 이름을 본다. 둘 다 모르면 food 다.
    /// 코스·게시글·장소 가져오기 매퍼도 이 표 하나를 쓴다
    static func category(code: String?, name: String?) -> PlaceCategory {
        code.flatMap(categoryByCode) ?? categoryByName(name)
    }

    private static func categoryByCode(_ code: String) -> PlaceCategory? {
        switch code {
        case "RESTAURANT": return .food
        case "CAFE": return .cafe
        case "ENTERTAINMENT": return .activity
        case "SHOPPING": return .shopping
        case "CONVENIENCE": return .convenience
        case "TOURISM": return .tourism
        case "ACCOMMODATION": return .accommodation
        default: return nil
        }
    }

    private static func categoryByName(_ name: String?) -> PlaceCategory {
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

    /// 서버 `ownershipStatus` 를 저장 관계로 바꾼다. 대소문자를 가리지 않고, 모르는 값은 nil 이다.
    /// 모르는 값을 무엇으로 둘지는 부르는 쪽이 정한다
    static func ownership(_ raw: String) -> PlaceOwnership? {
        switch raw.uppercased() {
        case "MINE": return .mine
        case "PARTNER": return .partner
        case "TOGETHER": return .together
        default: return nil
        }
    }

    /// 대표 사진을 맨 앞에 두고 나머지 사진을 잇는다.
    /// 같은 주소는 처음 한 번만 남기고, URL 로 못 읽는 값은 버린다
    static func photoURLs(thumbnailURL: String?, imageURLs: [String]) -> [URL] {
        var seen = Set<String>()
        return ([thumbnailURL].compactMap { $0 } + imageURLs)
            .filter { seen.insert($0).inserted }
            .compactMap(URL.init(string:))
    }

    // 서버가 도로명 없음을 nil 대신 "" 로 주기도 한다. Place.roadAddress 가 옵셔널이라
    // 여기서 빈 문자열도 nil 로 합쳐 둔다. 코스·게시글·가져오기 매퍼도 이 함수 하나를 쓴다
    static func roadAddress(_ raw: String?) -> String? {
        raw.flatMap { $0.isEmpty ? nil : $0 }
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
