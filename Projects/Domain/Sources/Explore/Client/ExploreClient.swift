//
//  ExploreClient.swift
//  Dulpick
//
//  Created by 이인호 on 8/7/26.
//

import Foundation
import ThirdParty

@DependencyClient
public struct ExploreClient: Sendable {
    public var contents: @Sendable (_ sort: ContentSort, _ page: Int, _ size: Int) async throws -> ContentPage
    public var searchContents: @Sendable (
        _ query: String, _ sort: ContentSort, _ page: Int, _ size: Int
    ) async throws -> ContentPage
    public var searchPlaces: @Sendable (
        _ query: String, _ page: Int, _ size: Int
    ) async throws -> PlacePage
    /// 장소 하나에 딸린 공개 게시물. placeID 는 공용 DB 장소 ID 다
    public var placeContents: @Sendable (
        _ placeID: Int, _ page: Int, _ size: Int
    ) async throws -> ContentPage
}

extension ExploreClient: TestDependencyKey {
    public static let testValue = ExploreClient()
    public static let previewValue = ExploreClient.mock
}

public extension DependencyValues {
    var exploreClient: ExploreClient {
        get { self[ExploreClient.self] }
        set { self[ExploreClient.self] = newValue }
    }
}
