//
//  HomeResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

struct HomeSummaryResponseDTO: Decodable, Sendable {
    let connected: Bool
    let myNickname: String?
    let partnerNickname: String?
    let currentDateCourse: HomeDateCourseResponseDTO?
}

// 지난 데이트 목록엔 status·version 이 안 와서 옵셔널이다
struct HomeDateCourseResponseDTO: Decodable, Sendable {
    let dateCourseId: Int
    let title: String
    let date: String
    let time: String?
    let status: String?
    let version: Int?
    let totalPlaceCount: Int
}

// 지난 데이트 코스 목록(GET /date-courses/past). totalCount 는 전체 데이트 횟수
struct PastDateCoursesResponseDTO: Decodable, Sendable {
    let dateCourses: [HomeDateCourseResponseDTO]
    let totalCount: Int
    let hasNext: Bool
}
