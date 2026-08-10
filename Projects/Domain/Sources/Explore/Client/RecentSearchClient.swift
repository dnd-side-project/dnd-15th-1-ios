//
//  RecentSearchClient.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import ThirdParty

@DependencyClient
public struct RecentSearchClient: Sendable {
    public var load: @Sendable () async -> [String] = { [] }
    public var add: @Sendable (_ term: String) async -> [String] = { _ in [] }
    public var remove: @Sendable (_ term: String) async -> [String] = { _ in [] }
    public var clear: @Sendable () async -> Void
}

extension RecentSearchClient: TestDependencyKey {
    public static let testValue = RecentSearchClient()
}

public extension DependencyValues {
    var recentSearchClient: RecentSearchClient {
        get { self[RecentSearchClient.self] }
        set { self[RecentSearchClient.self] = newValue }
    }
}
