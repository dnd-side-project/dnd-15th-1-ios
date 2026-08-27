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
        let sorted = (dto.places ?? []).sorted { $0.order < $1.order }
        let stops = sorted.map { CourseStop(place: mapPlace($0)) }
        let legs = sorted.dropLast().map { place -> CourseLeg? in
            guard let walk = place.walkToNext else { return nil }
            return CourseLeg(
                walkingMinutes: Int((Double(walk.durationSeconds) / 60).rounded()),
                distanceMeters: walk.distanceMeters
            )
        }
        return DateCourse(
            id: String(dto.dateCourseId),
            title: dto.title,
            scheduledDate: try Self.dateOnly(dto.date),
            scheduledTime: try Self.timeOnly(dto.time),
            status: status(dto.status),
            version: dto.version,
            stops: stops,
            legs: legs
        )
    }

    static func toDomain(_ dto: DateCourseSummaryResponseDTO) throws -> DateCourseSummary {
        DateCourseSummary(
            id: String(dto.dateCourseId),
            title: dto.title,
            scheduledAt: try scheduledAt(date: dto.date, time: dto.time),
            status: status(dto.status),
            version: dto.version,
            totalPlaceCount: dto.totalPlaceCount
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

    private static func mapPlace(_ dto: DateCoursePlaceResponseDTO) -> Place {
        let imageURLs = (dto.imageUrls ?? []).compactMap(URL.init(string:))
        let thumbnailURLs: [URL]
        if imageURLs.isEmpty, let thumb = dto.thumbnailUrl.flatMap(URL.init(string:)) {
            thumbnailURLs = [thumb]
        } else {
            thumbnailURLs = imageURLs
        }
        return Place(
            id: String(dto.placeId),
            kakaoPlaceID: nil,
            name: dto.name,
            category: category(dto.categoryName ?? ""),
            address: dto.address ?? "",
            roadAddress: dto.roadAddress ?? "",
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            bookmarkCount: 0,
            thumbnailURLs: thumbnailURLs
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

    // 서버가 `2026-08-05` 를 타임존 없이 준다. Asia/Seoul 그 날 자정으로 읽는다
    // 틀린 날짜를 만들어 아래로 흘리느니 실패로 끝낸다
    private static func dateOnly(_ date: String) throws -> Date {
        guard let scheduledDate = CourseDateFormat.date(from: date) else {
            throw CourseError.unknown
        }
        return scheduledDate
    }

    // 시간 없는 코스는 nil. 문자열이 있는데 못 읽으면 틀린 시간을 흘리지 않는다
    private static func timeOnly(_ time: String?) throws -> DateComponents? {
        guard let time else { return nil }
        guard let components = CourseDateFormat.timeComponents(from: time) else {
            throw CourseError.unknown
        }
        return components
    }

    // 요약은 시각 하나다. time 이 null 이면 날짜만 있는 응답이라 자정으로 읽는다
    private static func scheduledAt(date: String, time: String?) throws -> Date {
        guard let scheduledAt = CourseDateFormat.date(from: date, time: time ?? "00:00:00") else {
            throw CourseError.unknown
        }
        return scheduledAt
    }
}
