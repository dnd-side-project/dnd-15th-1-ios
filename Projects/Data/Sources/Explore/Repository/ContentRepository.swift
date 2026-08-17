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

    public func contents(page: Int, size: Int) async throws -> ContentPage {
        do {
            return ContentDTOMapper.toDomain(try await remote.contents(page: page, size: size))
        } catch {
            throw ExploreErrorMapper.map(error)
        }
    }
}
