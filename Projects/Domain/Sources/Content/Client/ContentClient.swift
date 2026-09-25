//
//  ContentClient.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Foundation
import ThirdParty

@DependencyClient
public struct ContentClient: Sendable {
    public var contents: @Sendable (_ sort: ContentSort, _ page: Int, _ size: Int) async throws -> ContentFeed
    public var searchContents: @Sendable (
        _ query: String, _ sort: ContentSort, _ page: Int, _ size: Int
    ) async throws -> ContentPage
    /// 장소 하나에 딸린 공개 게시물. placeID 는 `Place.placeID` 인 장소 번호다
    public var placeContents: @Sendable (
        _ placeID: String, _ page: Int, _ size: Int
    ) async throws -> ContentPage
    public var contentDetail: @Sendable (_ id: String) async throws -> PostDetailContent
}

extension ContentClient: TestDependencyKey {
    public static let testValue = ContentClient()
    public static let previewValue = ContentClient.mock
}

public extension DependencyValues {
    var contentClient: ContentClient {
        get { self[ContentClient.self] }
        set { self[ContentClient.self] = newValue }
    }
}
