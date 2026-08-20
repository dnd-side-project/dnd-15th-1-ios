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
}
