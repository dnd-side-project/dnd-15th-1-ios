//
//  ContentRemoteDataSource.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Foundation

public struct ContentRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func contents(page: Int, size: Int) async throws -> ContentPageResponseDTO {
        try await networkClient.request(ContentEndpoint.contents(page: page, size: size))
    }
}
