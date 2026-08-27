//
//  ContentPage.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

/// 게시물 목록의 한 페이지. hasNext 로만 다음 페이지 유무 판단
public struct ContentPage: Equatable, Sendable {
    public let items: [Content]
    public let hasNext: Bool
    // 탐색 탭 필터칩으로 쓰는 인기 태그. 첫 페이지 응답에 담겨 온다
    public let popularTags: [String]

    public init(items: [Content], hasNext: Bool, popularTags: [String]) {
        self.items = items
        self.hasNext = hasNext
        self.popularTags = popularTags
    }
}
