//
//  HomeClient+Mock.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//
//  임시 mock 데이터
//

import Foundation

public extension HomeClient {
    static let mock = HomeClient(
        home: { HomeSummary(connected: true, myNickname: "둘픽이", partnerNickname: "오몽이") },
        recentSavedPlaces: { _ in [] }
    )
}
