//
//  CourseDTOMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import Foundation
import SharedUtils

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
            // 지난 데이트 목록에는 상태가 없다
            status: dto.status.map { status($0) },
            totalPlaceCount: dto.totalPlaceCount
        )
    }

    /// 지난 데이트 한 페이지. 날짜를 못 읽는 코스가 하나라도 있으면 틀린 날짜를 보이지 않고 실패로 끝낸다
    static func toPage(_ dto: PastDateCoursesResponseDTO) throws -> PastDateCoursePage {
        PastDateCoursePage(
            courses: try dto.dateCourses.map(toDomain),
            totalCount: dto.totalCount,
            hasNext: dto.hasNext
        )
    }

    /// 코스에 담을 후보. 저장 장소 응답과 거의 같아 SavedPlace 로 옮긴다.
    /// 이 응답에 없는 카카오 번호·저장 수·저장 시각은 비워 둔다
    static func toDomain(_ dto: DateCoursePlaceCandidateResponseDTO) -> SavedPlace {
        SavedPlace(
            place: Place(
                placeID: String(dto.placeId),
                kakaoPlaceID: nil,
                name: dto.name,
                category: PlaceDTOMapper.category(code: nil, name: dto.categoryName),
                address: dto.address,
                roadAddress: PlaceDTOMapper.roadAddress(dto.roadAddress),
                coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
                bookmarkCount: nil,
                thumbnailURLs: PlaceDTOMapper.photoURLs(
                    thumbnailURL: dto.thumbnailUrl,
                    imageURLs: dto.imageUrls
                )
            ),
            // 모르는 저장 관계는 내가 저장한 것으로 둔다
            ownership: PlaceDTOMapper.ownership(dto.ownershipStatus) ?? .mine,
            alias: dto.alias,
            memo: nil,
            savedAt: nil
        )
    }

    private static func mapPlace(_ dto: DateCoursePlaceResponseDTO) -> Place {
        Place(
            placeID: String(dto.placeId),
            kakaoPlaceID: nil,
            name: dto.name,
            category: PlaceDTOMapper.category(code: nil, name: dto.categoryName),
            address: dto.address,
            roadAddress: PlaceDTOMapper.roadAddress(dto.roadAddress),
            coordinate: Coordinate(latitude: dto.latitude, longitude: dto.longitude),
            // 코스 응답에는 저장 수가 없다
            bookmarkCount: nil,
            thumbnailURLs: PlaceDTOMapper.photoURLs(
                thumbnailURL: dto.thumbnailUrl,
                imageURLs: dto.imageUrls ?? []
            )
        )
    }

    // 모르는 값이 오면 DRAFT 로 둔다. 홈은 CONFIRMED 만 보므로 안 뜨는 쪽이 덜 위험하다
    private static func status(_ raw: String) -> CourseStatus {
        switch raw.uppercased() {
        case "CONFIRMED": return .confirmed
        default: return .draft
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
