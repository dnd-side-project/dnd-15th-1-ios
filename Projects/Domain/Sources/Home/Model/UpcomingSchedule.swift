//
//  UpcomingSchedule.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//

import Foundation

// 다가오는 데이트 일정, 상단 배너에 표시. 코스짜기 연동 전까지 mock 고정
public struct UpcomingSchedule: Equatable, Sendable {
    public let date: String
    public let placeCount: Int

    public init(date: String, placeCount: Int) {
        self.date = date
        self.placeCount = placeCount
    }
}
