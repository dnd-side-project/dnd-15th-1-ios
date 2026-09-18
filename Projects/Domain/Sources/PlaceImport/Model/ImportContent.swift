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
    public let thumbnailURL: URL?
    public let author: ImportAuthor?
    /// 게시일. 서버 값을 못 읽으면 nil 이다
    public let publishedOn: Date?

    public init(
        title: String?,
        caption: String?,
        thumbnailURL: URL?,
        author: ImportAuthor?,
        publishedOn: Date?
    ) {
        self.title = title
        self.caption = caption
        self.thumbnailURL = thumbnailURL
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
