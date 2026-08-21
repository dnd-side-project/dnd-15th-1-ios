//
//  HomeResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

// 쓰는 필드만 선언한다. currentDateCourse 등 나머지 키는 디코딩에서 무시됨
struct HomeSummaryResponseDTO: Decodable, Sendable {
    let connected: Bool
    let myNickname: String?
    let partnerNickname: String?
}
