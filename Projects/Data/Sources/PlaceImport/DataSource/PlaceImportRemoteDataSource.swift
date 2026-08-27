//
//  PlaceImportRemoteDataSource.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Foundation

public struct PlaceImportRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func start(sourceUrl: String) async throws -> PlaceImportResponseDTO {
        try await networkClient.request(PlaceImportEndpoint.start(sourceUrl: sourceUrl))
    }

    func poll(importId: Int) async throws -> PlaceImportResponseDTO {
        try await networkClient.request(PlaceImportEndpoint.poll(importId: importId))
    }

    func confirm(importId: Int, candidateIDs: [Int]) async throws {
        try await networkClient.request(
            PlaceImportEndpoint.confirm(importId: importId, candidateIDs: candidateIDs)
        )
    }
}
