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
    public static func make(
        userDefaults: any UserDefaultsStorage,
        key: String = "recent-searches",
        maxCount: Int = 6
    ) -> RecentSearchClient {
        RecentSearchClient(
            load: {
                await load(userDefaults, key: key)
            },
            add: { term in
                var list = await load(userDefaults, key: key)
                list.removeAll { $0 == term }
                list.insert(term, at: 0)
                list = Array(list.prefix(maxCount))
                await save(list, to: userDefaults, key: key)
                return list
            },
            remove: { term in
                var list = await load(userDefaults, key: key)
                list.removeAll { $0 == term }
                await save(list, to: userDefaults, key: key)
                return list
            },
            clear: {
                await save([], to: userDefaults, key: key)
            }
        )
    }

    private static func load(
        _ storage: any UserDefaultsStorage,
        key: String
    ) async -> [String] {
        let terms: [String]? = try? await storage.get(forKey: key)
        return terms ?? []
    }

    private static func save(
        _ terms: [String],
        to storage: any UserDefaultsStorage,
        key: String
    ) async {
        try? await storage.save(terms, forKey: key)
    }
}
