//
//  Post.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Foundation

public struct Post: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let thumbnailURLs: [URL]
    public let placeCount: Int

    public init(
        id: String,
        title: String,
        thumbnailURLs: [URL],
        placeCount: Int
    ) {
        self.id = id
        self.title = title
        self.thumbnailURLs = thumbnailURLs
        self.placeCount = placeCount
    }
}
