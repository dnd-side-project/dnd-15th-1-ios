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

    func start(sourceURL: String) async throws -> PlaceImportResponseDTO {
        try await networkClient.request(PlaceImportEndpoint.start(sourceURL: sourceURL))
    }

    func poll(importID: String) async throws -> PlaceImportResponseDTO {
        try await networkClient.request(PlaceImportEndpoint.poll(importID: importID))
    }

    func confirm(importID: String, candidateIDs: [Int]) async throws {
        try await networkClient.request(
            PlaceImportEndpoint.confirm(importID: importID, candidateIDs: candidateIDs)
        )
    }
}
