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

    public func start(sourceURL: URL) async throws -> PlaceImport {
        do {
            return PlaceImportDTOMapper.toDomain(try await remote.start(sourceURL: sourceURL.absoluteString))
        } catch {
            throw PlaceImportErrorMapper.map(error)
        }
    }

    public func poll(importID: String) async throws -> PlaceImport {
        do {
            return PlaceImportDTOMapper.toDomain(try await remote.poll(importID: importID))
        } catch {
            throw PlaceImportErrorMapper.map(error)
        }
    }

    // 서버는 후보 번호를 숫자로 받는다. 숫자가 아닌 번호가 있으면 보내지 않고 unknown 으로 끝낸다
    public func confirm(importID: String, candidateIDs: [String]) async throws {
        do {
            let numbers = try candidateIDs.map { raw -> Int in
                guard let number = Int(raw) else { throw PlaceImportError.unknown }
                return number
            }
            try await remote.confirm(importID: importID, candidateIDs: numbers)
        } catch {
            throw PlaceImportErrorMapper.map(error)
        }
    }
}
