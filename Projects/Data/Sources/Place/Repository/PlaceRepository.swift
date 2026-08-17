//
//  PlaceRepository.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

public struct PlaceRepository: Sendable {
    private let remote: PlaceRemoteDataSource

    public init(remote: PlaceRemoteDataSource) {
        self.remote = remote
    }

    public func savedPlaces() async throws -> [SavedPlace] {
        do {
            return try await remote.savedPlaces().map(PlaceDTOMapper.toDomain)
        } catch {
            throw PlaceErrorMapper.map(error)
        }
    }
}
