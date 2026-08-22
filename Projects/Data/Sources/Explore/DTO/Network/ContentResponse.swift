//
//  ContentResponse.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation

// 그리드가 쓰는 필드만 선언. author/engagement/places 등 나머지 키는 디코딩에서 무시됨
struct ContentPageResponseDTO: Decodable, Sendable {
    let contents: [ContentResponseDTO]
    let hasNext: Bool
    let popularTags: [String]?
}

struct ContentResponseDTO: Decodable, Sendable {
    let contentId: Int
    let title: String
    let thumbnailUrl: String?
    let placeCount: Int
}
