//
//  ContentRemoteDataSource.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Domain
import Foundation

public struct ContentRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func contents(sort: ContentSort, page: Int, size: Int) async throws -> ContentPageResponseDTO {
        try await networkClient.request(ContentEndpoint.contents(sort: sort, page: page, size: size))
    }

    func searchContents(
        query: String,
        sort: ContentSort,
        page: Int,
        size: Int
    ) async throws -> ContentPageResponseDTO {
        try await networkClient.request(
            ContentEndpoint.search(query: query, sort: sort, page: page, size: size)
        )
    }

    func contentDetail(id: String) async throws -> ContentDetailResponseDTO {
        try await networkClient.request(ContentEndpoint.detail(id: id))
    }

    func placeContents(placeID: Int, page: Int, size: Int) async throws -> ContentPageResponseDTO {
        try await networkClient.request(
            ContentEndpoint.placeContents(placeID: placeID, page: page, size: size)
        )
    }
}
