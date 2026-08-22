//
//  ContentRepository.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

public struct ContentRepository: Sendable {
    private let remote: ContentRemoteDataSource

    public init(remote: ContentRemoteDataSource) {
        self.remote = remote
    }

    public func contents(sort: ContentSort, page: Int, size: Int) async throws -> ContentPage {
        do {
            return ContentDTOMapper.toDomain(try await remote.contents(sort: sort, page: page, size: size))
        } catch {
            throw ExploreErrorMapper.map(error)
        }
    }

    public func searchContents(
        query: String,
        sort: ContentSort,
        page: Int,
        size: Int
    ) async throws -> ContentPage {
        do {
            return ContentDTOMapper.toDomain(
                try await remote.searchContents(query: query, sort: sort, page: page, size: size)
            )
        } catch {
            throw ExploreErrorMapper.map(error)
        }
    }

    public func contentDetail(id: String) async throws -> PostDetailContent {
        do {
            return ContentDTOMapper.toDetail(try await remote.contentDetail(id: id))
        } catch {
            throw ExploreErrorMapper.map(error)
        }
    }
}
