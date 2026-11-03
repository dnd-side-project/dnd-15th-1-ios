//
//  CourseResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

struct DateCourseResponseDTO: Decodable, Sendable {
    let dateCourseId: Int
    let title: String
    let date: String
    let time: String?
    let status: String
    let version: Int
    let totalPlaceCount: Int?
    let places: [DateCoursePlaceResponseDTO]?
}

struct CurrentDateCourseResponseDTO: Decodable, Sendable {
    let currentDateCourse: DateCourseSummaryResponseDTO?
}

// 지난 데이트 목록엔 status·version 이 안 와서 옵셔널이다
struct DateCourseSummaryResponseDTO: Decodable, Sendable {
    let dateCourseId: Int
    let title: String
    let date: String
    let time: String?
    let status: String?
    let version: Int?
    let totalPlaceCount: Int
}

struct DateCoursePlaceResponseDTO: Decodable, Sendable {
    let order: Int
    let placeId: Int64
    let name: String
    let address: String
    let roadAddress: String?
    let latitude: Double
    let longitude: Double
    let category: String?
    let categoryName: String?
    let thumbnailUrl: String?
    let imageUrls: [String]?
    let walkToNext: WalkToNextResponseDTO?
}

struct WalkToNextResponseDTO: Decodable, Sendable {
    let distanceMeters: Int
    let durationSeconds: Int
    /// 명세상 필수지만 키가 없거나 형식이 틀리면 빈 배열로 읽는다. 키 하나로 코스 전체 읽기가 깨지지 않게 한다
    let path: [RoutePointResponseDTO]
    /// 도보 30분 이상 구간에만 온다. 해당하지 않거나 조회하지 못하면 null. 형식이 틀려도 nil 로 읽는다
    let transit: TransitToNextResponseDTO?

    init(
        distanceMeters: Int,
        durationSeconds: Int,
        path: [RoutePointResponseDTO] = [],
        transit: TransitToNextResponseDTO? = nil
    ) {
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.path = path
        self.transit = transit
    }
}

extension WalkToNextResponseDTO {
    private enum CodingKeys: String, CodingKey {
        case distanceMeters
        case durationSeconds
        case path
        case transit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        distanceMeters = try container.decode(Int.self, forKey: .distanceMeters)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        path = (try? container.decodeIfPresent([RoutePointResponseDTO].self, forKey: .path)) ?? []
        transit = try? container.decodeIfPresent(TransitToNextResponseDTO.self, forKey: .transit)
    }
}

/// `type`·`transfers`·`fare` 는 화면이 안 쓰므로 읽지 않는다
struct TransitToNextResponseDTO: Decodable, Sendable {
    let distanceMeters: Int
    let durationSeconds: Int
    /// 이동 순서대로. 키가 없거나 형식이 틀리면 빈 배열
    let legs: [TransitLegResponseDTO]
}

extension TransitToNextResponseDTO {
    private enum CodingKeys: String, CodingKey {
        case distanceMeters
        case durationSeconds
        case legs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        distanceMeters = try container.decode(Int.self, forKey: .distanceMeters)
        durationSeconds = try container.decode(Int.self, forKey: .durationSeconds)
        legs = (try? container.decodeIfPresent([TransitLegResponseDTO].self, forKey: .legs)) ?? []
    }
}

/// 구간 좌표만 읽는다. 노선·정류장·안내 문구는 화면이 안 쓴다
struct TransitLegResponseDTO: Decodable, Sendable {
    /// 키가 없거나 형식이 틀리면 빈 배열
    let path: [RoutePointResponseDTO]
}

extension TransitLegResponseDTO {
    private enum CodingKeys: String, CodingKey {
        case path
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = (try? container.decodeIfPresent([RoutePointResponseDTO].self, forKey: .path)) ?? []
    }
}

/// WGS84 좌표
struct RoutePointResponseDTO: Decodable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct DateCoursePartnerNotifyResponseDTO: Decodable, Sendable {
    let notified: Bool
    let partnerMemberId: Int64
}

struct DateCoursePlacePoolResponseDTO: Decodable, Sendable {
    let places: [DateCoursePlaceCandidateResponseDTO]
}

/// 코스 장소 검색 한 페이지(GET /date-courses/places/search). 항목은 코스 후보와 같은 모양이다
struct DateCoursePlaceSearchPageResponseDTO: Decodable, Sendable {
    let places: [DateCoursePlaceCandidateResponseDTO]
    /// 0 부터 센다
    let page: Int
    /// 지금 화면이 안 읽는다. 서버가 한 페이지 10건을 준다
    let size: Int
    let hasNext: Bool
}

/// `region` · `savedAt` · `category`(카카오 분류 단계값) 는 담지 않는다.
/// 지금 코스 장소 선택 화면이 안 읽는다
struct DateCoursePlaceCandidateResponseDTO: Decodable, Sendable {
    let placeId: Int
    let name: String
    // 지번 주소는 명세상 필수다. 도로명은 없는 장소가 있어 옵셔널
    let address: String
    let roadAddress: String?
    let latitude: Double
    let longitude: Double
    let categoryName: String
    let ownershipStatus: String
    let alias: String?
    let thumbnailUrl: String?
    let imageUrls: [String]
}

// 지난 데이트 코스 목록(GET /date-courses/past). totalCount 는 전체 데이트 횟수
struct PastDateCoursesResponseDTO: Decodable, Sendable {
    let dateCourses: [DateCourseSummaryResponseDTO]
    let totalCount: Int
    let hasNext: Bool
}
