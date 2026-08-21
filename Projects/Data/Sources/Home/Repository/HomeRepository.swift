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

    public func recentSavedPlaces(size: Int) async throws -> [SavedPlace] {
        do {
            return try await remote.recentSavedPlaces(size: size).map(PlaceDTOMapper.toDomain)
        } catch {
            throw HomeErrorMapper.map(error)
        }
    }

    public func pastDates(size: Int) async throws -> [DateSchedule] {
        do {
            return HomeDTOMapper.toPastDates(try await remote.pastDates(size: size))
        } catch {
            throw HomeErrorMapper.map(error)
        }
    }

    public func pastCourses(size: Int) async throws -> [DateSchedule] {
        do {
            return HomeDTOMapper.toPastDates(try await remote.pastCourses(size: size))
        } catch {
            throw HomeErrorMapper.map(error)
        }
    }
}
