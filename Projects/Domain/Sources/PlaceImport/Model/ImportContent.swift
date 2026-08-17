//
//  ImportContent.swift
//  Dulpick
//
//  Created by 이인호 on 8/16/26.
//

import Foundation

public struct ImportContent: Equatable, Sendable {
    public let title: String?
    public let caption: String?
    public let thumbnailUrl: String?
    public let author: ImportAuthor?
    public let publishedOn: String?

    public init(
        title: String?,
        caption: String?,
        thumbnailUrl: String?,
        author: ImportAuthor?,
        publishedOn: String?
    ) {
        self.title = title
        self.caption = caption
        self.thumbnailUrl = thumbnailUrl
        self.author = author
        self.publishedOn = publishedOn
    }
}

public struct ImportAuthor: Equatable, Sendable {
    public let displayName: String
    public let username: String

    public init(displayName: String, username: String) {
        self.displayName = displayName
        self.username = username
    }
}
