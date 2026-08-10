//
//  Place.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Foundation

public struct Place: Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: PlaceCategory
    public let bookmarkCount: Int
    public let thumbnailURLs: [URL]

    public init(
        id: String,
        name: String,
        category: PlaceCategory,
        bookmarkCount: Int,
        thumbnailURLs: [URL]
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.bookmarkCount = bookmarkCount
        self.thumbnailURLs = thumbnailURLs
    }
}
