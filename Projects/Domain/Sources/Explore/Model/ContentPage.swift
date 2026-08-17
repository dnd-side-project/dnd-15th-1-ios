//
//  ContentPage.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

/// 콘텐츠 목록의 한 페이지. hasNext 로만 다음 페이지 유무 판단
public struct ContentPage: Equatable, Sendable {
    public let items: [Content]
    public let hasNext: Bool

    public init(items: [Content], hasNext: Bool) {
        self.items = items
        self.hasNext = hasNext
    }
}
