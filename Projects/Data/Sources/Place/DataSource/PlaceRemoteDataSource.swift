//
//  PlaceRemoteDataSource.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Foundation

public struct PlaceRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func savedPlaces() async throws -> [SavedPlaceResponseDTO] {
        try await networkClient.request(PlaceEndpoint.savedPlaces)
    }

    func searchPlaces(query: String, page: Int, size: Int) async throws -> PlaceSearchResponseDTO {
        try await networkClient.request(PlaceEndpoint.search(query: query, page: page, size: size))
    }

    func save(kakaoPlaceID: String, query: String, alias: String?) async throws -> SavedPlaceResponseDTO {
        try await networkClient.request(
            PlaceEndpoint.save(kakaoPlaceID: kakaoPlaceID, query: query, alias: alias)
        )
    }

    func remove(placeID: String) async throws {
        try await networkClient.request(PlaceEndpoint.remove(placeID: placeID))
    }

    func detail(placeID: Int) async throws -> PlaceDetailResponseDTO {
        try await networkClient.request(PlaceEndpoint.detail(placeID: placeID))
    }

    func kakaoDetail(kakaoPlaceID: String, query: String) async throws -> PlaceDetailResponseDTO {
        try await networkClient.request(
            PlaceEndpoint.kakaoDetail(kakaoPlaceID: kakaoPlaceID, query: query)
        )
    }

    func updateAlias(placeID: Int, alias: String?) async throws -> SavedPlaceResponseDTO {
        try await networkClient.request(
            PlaceEndpoint.updateAlias(placeID: placeID, alias: alias)
        )
    }
}
