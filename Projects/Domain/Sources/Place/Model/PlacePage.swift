//
//  PlacePage.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation

/// 장소 검색 한 페이지. hasNext 로만 다음 페이지 유무 판단
public struct PlacePage: Equatable, Sendable {
    public let items: [Place]
    public let hasNext: Bool

    public init(items: [Place], hasNext: Bool) {
        self.items = items
        self.hasNext = hasNext
    }
}
