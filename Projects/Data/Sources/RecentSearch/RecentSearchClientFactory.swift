//
//  RecentSearchClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/9/26.
//

import CoreStorage
import Domain
import Foundation

public enum RecentSearchClientFactory {
    private static let key = "recent-searches"
    private static let maxCount = 6

    public static func make(userDefaults: any UserDefaultsStorage) -> RecentSearchClient {
        RecentSearchClient(
            load: {
                await load(userDefaults)
            },
            add: { term in
                var list = await load(userDefaults)
                list.removeAll { $0 == term }
                list.insert(term, at: 0)
                list = Array(list.prefix(maxCount))
                await save(list, to: userDefaults)
                return list
            },
            remove: { term in
                var list = await load(userDefaults)
                list.removeAll { $0 == term }
                await save(list, to: userDefaults)
                return list
            },
            clear: {
                await save([], to: userDefaults)
            }
        )
    }

    private static func load(_ storage: any UserDefaultsStorage) async -> [String] {
        let terms: [String]? = try? await storage.get(forKey: key)
        return terms ?? []
    }

    private static func save(_ terms: [String], to storage: any UserDefaultsStorage) async {
        try? await storage.save(terms, forKey: key)
    }
}
