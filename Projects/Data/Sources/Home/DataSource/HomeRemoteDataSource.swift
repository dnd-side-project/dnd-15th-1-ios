//
//  HomeRemoteDataSource.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import CoreNetwork
import Foundation

public struct HomeRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func home() async throws -> HomeSummaryResponseDTO {
        try await networkClient.request(HomeEndpoint.home)
    }
}
