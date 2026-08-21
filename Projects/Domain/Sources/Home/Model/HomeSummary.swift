//
//  HomeSummary.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

/// 홈 상단 요약(`GET /api/v1/home`). 연결 여부·내 닉네임·파트너 닉네임
public struct HomeSummary: Equatable, Sendable {
    public let connected: Bool
    public let myNickname: String
    public let partnerNickname: String?

    public init(connected: Bool, myNickname: String, partnerNickname: String?) {
        self.connected = connected
        self.myNickname = myNickname
        self.partnerNickname = partnerNickname
    }
}
