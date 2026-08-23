//
//  ExploreClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

public enum ExploreClientFactory {
    public static func make(session: AuthSessionAssembly) -> ExploreClient {
        let repository = ContentRepository(
            remote: ContentRemoteDataSource(networkClient: session.authedClient)
        )
        let placeRepository = PlaceRepository(
            remote: PlaceRemoteDataSource(networkClient: session.authedClient)
        )
        return ExploreClient(
            contents: { sort, page, size in
                try await repository.contents(sort: sort, page: page, size: size)
            },
            searchContents: { query, sort, page, size in
                try await repository.searchContents(query: query, sort: sort, page: page, size: size)
            },
            searchPlaces: { query, page, size in
                try await placeRepository.searchPlaces(query: query, page: page, size: size)
            },
            placeContents: { placeID, page, size in
                try await repository.placeContents(placeID: placeID, page: page, size: size)
            }
        )
    }
}
