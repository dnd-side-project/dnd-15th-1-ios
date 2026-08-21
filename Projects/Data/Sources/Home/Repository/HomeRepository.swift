//
//  HomeRepository.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import Foundation

public struct HomeRepository: Sendable {
    private let remote: HomeRemoteDataSource

    public init(remote: HomeRemoteDataSource) {
        self.remote = remote
    }

    public func home() async throws -> HomeSummary {
        do {
            return HomeDTOMapper.toDomain(try await remote.home())
        } catch {
            throw HomeErrorMapper.map(error)
        }
    }
}
