//
//  DateSchedule.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//

import Foundation

// 지난 데이트 일정, 코스짜기 연동 전까지 mock 고정
public struct DateSchedule: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let placeCount: Int
    public let date: String

    public init(
        id: String,
        title: String,
        placeCount: Int,
        date: String
    ) {
        self.id = id
        self.title = title
        self.placeCount = placeCount
        self.date = date
    }
}
