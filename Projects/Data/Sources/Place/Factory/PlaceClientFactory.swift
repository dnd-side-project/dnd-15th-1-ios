//
//  PlaceClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

public enum PlaceClientFactory {
    /// 명세에 size 가 없어도 서버가 받아 준다. 한 페이지 10건 고정이라 여기서 넘긴다
    private static let pageSize = 10

    public static func make(session: AuthSessionAssembly) -> PlaceClient {
        let repository = PlaceRepository(
            remote: PlaceRemoteDataSource(networkClient: session.authedClient)
        )
        return PlaceClient(
            savedPlaces: {
                try await repository.savedPlaces()
            },
            searchPlaces: { query, page in
                try await repository.searchPlaces(query: query, page: page, size: pageSize)
            },
            savePlace: { kakaoPlaceID, query, alias, _ in
                try await repository.save(kakaoPlaceID: kakaoPlaceID, query: query, alias: alias)
            },
            removePlace: { placeID in
                try await repository.remove(placeID: placeID)
            },
            placeDetail: { placeID in
                try await repository.detail(placeID: placeID)
            },
            kakaoPlaceDetail: { kakaoPlaceID, query in
                try await repository.kakaoDetail(kakaoPlaceID: kakaoPlaceID, query: query)
            },
            updateAlias: { placeID, alias in
                try await repository.updateAlias(placeID: placeID, alias: alias)
            }
        )
    }
}
