//
//  HomeMock.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//
//  임시 mock 데이터
//

import Foundation

public extension DateSchedule {
    static let mocks: [DateSchedule] = [
        DateSchedule(id: "1", title: "성수역 데이트", placeCount: 5, date: "26.08.06"),
        DateSchedule(id: "2", title: "강남역 데이트", placeCount: 3, date: "26.07.28"),
        DateSchedule(id: "3", title: "한강 데이트", placeCount: 4, date: "26.07.14"),
    ]
}

public extension DateCourseSummary {
    static let mock = DateCourseSummary(
        id: "1",
        title: "성수동 데이트",
        scheduledAt: Date(timeIntervalSince1970: 1_785_931_200),
        status: .confirmed,
        version: 1,
        totalPlaceCount: 5
    )
}
