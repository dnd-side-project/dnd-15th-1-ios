//
//  UpcomingSchedule.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//

import Foundation

// 다가오는 데이트 일정, 상단 배너에 표시. 코스 제목과 장소 수를 보여준다
public struct UpcomingSchedule: Equatable, Sendable {
    public let title: String
    public let placeCount: Int

    public init(title: String, placeCount: Int) {
        self.title = title
        self.placeCount = placeCount
    }
}
