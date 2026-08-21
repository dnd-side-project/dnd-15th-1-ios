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

    // 응답 항목이 저장 장소 목록과 동일해 SavedPlaceResponseDTO 를 재사용한다
    func recentSavedPlaces(size: Int) async throws -> [SavedPlaceResponseDTO] {
        try await networkClient.request(HomeEndpoint.recentSavedPlaces(size: size))
    }
}
