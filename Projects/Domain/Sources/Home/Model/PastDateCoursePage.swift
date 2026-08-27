//
//  PastDateCoursePage.swift
//  Dulpick
//
//  Created by 이인호 on 8/22/26.
//

import Foundation

/// 지난 데이트 코스 한 페이지. totalCount 는 전체 데이트 횟수, hasNext 로 다음 페이지 유무 판단
public struct PastDateCoursePage: Equatable, Sendable {
    public let courses: [DateSchedule]
    public let totalCount: Int
    public let hasNext: Bool

    public init(courses: [DateSchedule], totalCount: Int, hasNext: Bool) {
        self.courses = courses
        self.totalCount = totalCount
        self.hasNext = hasNext
    }
}
