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

/// 지도 검색 전용 최근 검색어. 탐색 탭과 저장 칸을 나눈다.
///
/// 계약은 `recentSearchClient` 와 같다. 저장 키만 다르다.
public enum MapRecentSearchClientKey: TestDependencyKey {
    public static let testValue = RecentSearchClient()
}

public extension DependencyValues {
    var mapRecentSearchClient: RecentSearchClient {
        get { self[MapRecentSearchClientKey.self] }
        set { self[MapRecentSearchClientKey.self] = newValue }
    }
}
