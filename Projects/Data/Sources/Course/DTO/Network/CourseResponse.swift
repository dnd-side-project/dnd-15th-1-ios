//
//  CourseResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

/// `walkToNext` 와 `places` 는 담지 않는다. `POST /api/v1/date-courses` 는
/// 장소 없는 DRAFT 를 만들어서 늘 빈 배열이고, 담을 곳인 `CourseLeg` 가
/// 명세와 단위·위치가 어긋난다. DND-52 가 실제 응답을 보며 고친다
struct DateCourseResponseDTO: Decodable, Sendable {
    let dateCourseId: Int
    let title: String
    let date: String
    let time: String
    let status: String
    let version: Int
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
