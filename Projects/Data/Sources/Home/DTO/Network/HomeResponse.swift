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

// 현재 데이트 코스·지난 데이트가 같은 형태로 온다. 쓰는 필드만 선언
struct HomeDateCourseResponseDTO: Decodable, Sendable {
    let dateCourseId: Int
    let title: String
    let date: String
    let totalPlaceCount: Int
}

// 지난 데이트 코스 목록(GET /date-courses/past). totalCount 는 전체 데이트 횟수
struct PastDateCoursesResponseDTO: Decodable, Sendable {
    let dateCourses: [HomeDateCourseResponseDTO]
    let totalCount: Int
    let hasNext: Bool
}
