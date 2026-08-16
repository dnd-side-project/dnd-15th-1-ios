//
//  HomeMock.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//
//  임시 mock 데이터
//

import Foundation

public extension SavedPlace {
    static let mocks: [SavedPlace] = [
        SavedPlace(id: "1", name: "he november 라운지 강남역", category: .cafe),
        SavedPlace(id: "2", name: "까치화방 카페 강남점", category: .cafe),
        SavedPlace(id: "3", name: "만약 카페명이 너무 길다면 ...으로 처리하면...", category: .cafe),
        SavedPlace(id: "4", name: "성수동 감성 카페", category: .cafe),
        SavedPlace(id: "5", name: "을지로 노포 맛집", category: .food),
    ]
}

public extension DateSchedule {
    static let mocks: [DateSchedule] = [
        DateSchedule(id: "1", title: "성수역 데이트", placeCount: 5, date: "26.08.06"),
        DateSchedule(id: "2", title: "강남역 데이트", placeCount: 3, date: "26.07.28"),
        DateSchedule(id: "3", title: "한강 데이트", placeCount: 4, date: "26.07.14"),
    ]
}

public extension UpcomingSchedule {
    static let mock = UpcomingSchedule(date: "08.05", placeCount: 5)
}
