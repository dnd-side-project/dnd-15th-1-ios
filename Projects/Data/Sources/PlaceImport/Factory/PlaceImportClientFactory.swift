//
//  PlaceImportClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Domain
import Foundation

public enum PlaceImportClientFactory {
    public static func make(session: AuthSessionAssembly) -> PlaceImportClient {
        makeClient(repository: makeRepo(session: session))
    }

    private static func makeClient(repository: PlaceImportRepository) -> PlaceImportClient {
        PlaceImportClient(
            start: { sourceUrl in
                try await repository.start(sourceUrl: sourceUrl)
            },
            poll: { importId in
                try await repository.poll(importId: importId)
            },
            confirm: { importId, candidateIDs in
                try await repository.confirm(importId: importId, candidateIDs: candidateIDs)
            }
        )
    }

    private static func makeRepo(session: AuthSessionAssembly) -> PlaceImportRepository {
        PlaceImportRepository(
            remote: PlaceImportRemoteDataSource(networkClient: session.authedClient)
        )
    }
}
