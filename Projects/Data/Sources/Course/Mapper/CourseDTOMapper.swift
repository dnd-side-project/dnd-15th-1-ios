//
//  CourseDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import Foundation

enum CourseDTOMapper {
    static func toDomain(_ dto: DateCourseResponseDTO) throws -> DateCourse {
        DateCourse(
            id: String(dto.dateCourseId),
            title: dto.title,
            scheduledAt: try scheduledAt(date: dto.date, time: dto.time),
            status: status(dto.status),
            version: dto.version,
            stops: [],
            legs: []
        )
    }

    static func toDomain(_ dto: DateCoursePlaceCandidateResponseDTO) -> CoursePlaceCandidate {
        CoursePlaceCandidate(
            id: String(dto.placeId),
            name: dto.name,
            address: dto.address,
            category: category(dto.categoryName),
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            ownership: ownership(dto.ownershipStatus),
            alias: dto.alias,
            thumbnailURLs: dto.imageUrls.compactMap(URL.init(string:))
        )
    }

    // 모르는 값이 오면 DRAFT 로 둔다. 홈은 CONFIRMED 만 보므로 안 뜨는 쪽이 덜 위험하다
    private static func status(_ raw: String) -> CourseStatus {
        CourseStatus(rawValue: raw.lowercased()) ?? .draft
    }

    private static func ownership(_ raw: String) -> PlaceOwnership {
        PlaceOwnership(rawValue: raw.lowercased()) ?? .mine
    }

    // 서버 categoryName(한글) 을 카테고리로 매핑. PlaceDTOMapper 와 같은 표다
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

    // 서버가 `2026-08-05` 와 `13:00:00` 을 따로 준다. 타임존 표기가 없고 Asia/Seoul 기준이다
    // 틀린 시각을 만들어 아래로 흘리느니 실패로 끝낸다
    private static func scheduledAt(date: String, time: String) throws -> Date {
        guard let scheduledAt = CourseDateFormat.date(from: date, time: time) else {
            throw CourseError.unknown
        }
        return scheduledAt
    }
}
