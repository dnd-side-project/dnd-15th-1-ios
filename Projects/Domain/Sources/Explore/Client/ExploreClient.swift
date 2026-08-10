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
    public var popularPosts: @Sendable () async throws -> [Post]
    public var searchPosts: @Sendable (_ query: String) async throws -> [Post]
    public var searchPlaces: @Sendable (_ query: String) async throws -> [Place]
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
