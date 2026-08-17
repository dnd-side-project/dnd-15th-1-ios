//
//  PlaceImportRepository.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

public struct PlaceImportRepository: Sendable {
    private let remote: PlaceImportRemoteDataSource

    public init(remote: PlaceImportRemoteDataSource) {
        self.remote = remote
    }

    public func start(sourceUrl: String) async throws -> PlaceImport {
        do {
            return PlaceImportDTOMapper.toDomain(try await remote.start(sourceUrl: sourceUrl))
        } catch {
            throw PlaceImportErrorMapper.map(error)
        }
    }

    public func poll(importId: Int) async throws -> PlaceImport {
        do {
            return PlaceImportDTOMapper.toDomain(try await remote.poll(importId: importId))
        } catch {
            throw PlaceImportErrorMapper.map(error)
        }
    }

    public func confirm(importId: Int, candidateIDs: [Int]) async throws {
        do {
            try await remote.confirm(importId: importId, candidateIDs: candidateIDs)
        } catch {
            throw PlaceImportErrorMapper.map(error)
        }
    }
}
