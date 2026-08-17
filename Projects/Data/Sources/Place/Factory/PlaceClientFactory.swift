//
//  PlaceClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

public enum PlaceClientFactory {
    public static func make(session: AuthSessionAssembly) -> PlaceClient {
        let repository = PlaceRepository(
            remote: PlaceRemoteDataSource(networkClient: session.authedClient)
        )
        // searchPlaces / savePlace 는 아직 서버 연동 전이라 mock 유지
        return PlaceClient(
            savedPlaces: {
                try await repository.savedPlaces()
            },
            searchPlaces: PlaceClient.mock.searchPlaces,
            savePlace: PlaceClient.mock.savePlace
        )
    }
}
