//
//  ContentClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

public enum ContentClientFactory {
    public static func make(session: AuthSessionAssembly) -> ContentClient {
        let repository = ContentRepository(
            remote: ContentRemoteDataSource(networkClient: session.authedClient)
        )
        return ContentClient(
            contents: { sort, page, size in
                try await repository.contents(sort: sort, page: page, size: size)
            },
            searchContents: { query, sort, page, size in
                try await repository.searchContents(query: query, sort: sort, page: page, size: size)
            },
            placeContents: { placeID, page, size in
                try await repository.placeContents(placeID: placeID, page: page, size: size)
            },
            contentDetail: { id in
                try await repository.contentDetail(id: id)
            }
        )
    }
}
