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

    public func searchPlaces(query: String, page: Int, size: Int) async throws -> PlacePage {
        do {
            return PlaceDTOMapper.toSearchPage(
                try await remote.searchPlaces(query: query, page: page, size: size),
                page: page
            )
        } catch {
            throw PlaceErrorMapper.map(error)
        }
    }

    public func save(kakaoPlaceID: String, query: String, alias: String?) async throws -> SavedPlace {
        do {
            return PlaceDTOMapper.toDomain(
                try await remote.save(kakaoPlaceID: kakaoPlaceID, query: query, alias: alias)
            )
        } catch {
            throw PlaceErrorMapper.map(error)
        }
    }

    public func remove(placeID: String) async throws {
        do {
            try await remote.remove(placeID: placeID)
        } catch {
            throw PlaceErrorMapper.map(error)
        }
    }

    public func detail(placeID: Int) async throws -> PlaceDetail {
        do {
            return PlaceDTOMapper.toDomain(try await remote.detail(placeID: placeID))
        } catch {
            throw PlaceErrorMapper.map(error)
        }
    }

    public func kakaoDetail(kakaoPlaceID: String, query: String) async throws -> PlaceDetail {
        do {
            return PlaceDTOMapper.toDomain(
                try await remote.kakaoDetail(kakaoPlaceID: kakaoPlaceID, query: query)
            )
        } catch {
            throw PlaceErrorMapper.map(error)
        }
    }

    public func updateAlias(placeID: Int, alias: String?) async throws -> SavedPlace {
        do {
            return PlaceDTOMapper.toDomain(
                try await remote.updateAlias(placeID: placeID, alias: alias)
            )
        } catch {
            throw PlaceErrorMapper.map(error)
        }
    }
}
