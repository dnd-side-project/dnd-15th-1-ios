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
            start: { sourceURL in
                try await repository.start(sourceURL: sourceURL)
            },
            poll: { importID in
                try await repository.poll(importID: importID)
            },
            confirm: { importID, candidateIDs in
                try await repository.confirm(importID: importID, candidateIDs: candidateIDs)
            }
        )
    }

    private static func makeRepo(session: AuthSessionAssembly) -> PlaceImportRepository {
        PlaceImportRepository(
            remote: PlaceImportRemoteDataSource(networkClient: session.authedClient)
        )
    }
}
