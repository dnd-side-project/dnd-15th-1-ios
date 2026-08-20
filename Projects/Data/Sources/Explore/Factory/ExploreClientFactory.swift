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
        // searchPlaces(장소 검색)는 아직 서버 연동 전이라 mock 유지
        return ExploreClient(
            contents: { sort, page, size in
                try await repository.contents(sort: sort, page: page, size: size)
            },
            searchContents: { query, sort, page, size in
                try await repository.searchContents(query: query, sort: sort, page: page, size: size)
            },
            searchPlaces: ExploreClient.mock.searchPlaces
        )
    }
}
