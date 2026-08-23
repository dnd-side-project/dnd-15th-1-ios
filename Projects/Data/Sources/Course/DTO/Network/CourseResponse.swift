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

struct DateCourseSummaryResponseDTO: Decodable, Sendable {
    let dateCourseId: Int
    let title: String
    let date: String
    let time: String?
    let status: String
    let version: Int
    let totalPlaceCount: Int
}

struct DateCoursePlaceResponseDTO: Decodable, Sendable {
    let order: Int
    let placeId: Int64
    let name: String
    let address: String?
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
}

struct DateCoursePartnerNotifyResponseDTO: Decodable, Sendable {
    let notified: Bool
    let partnerMemberId: Int64
}

struct DateCoursePlacePoolResponseDTO: Decodable, Sendable {
    let places: [DateCoursePlaceCandidateResponseDTO]
}

/// `region` · `roadAddress` · `savedAt` · `category`(카카오 분류 단계값) 는 담지 않는다.
/// 지금 코스 장소 선택 화면이 안 읽는다
struct DateCoursePlaceCandidateResponseDTO: Decodable, Sendable {
    let placeId: Int
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let categoryName: String
    let ownershipStatus: String
    let alias: String?
    let imageUrls: [String]
}
