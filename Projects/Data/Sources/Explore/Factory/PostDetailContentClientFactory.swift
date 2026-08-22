//
//  PostDetailContentClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/22/26.
//

import Domain
import Foundation

public enum PostDetailContentClientFactory {
    public static func make(session: AuthSessionAssembly) -> PostDetailContentClient {
        let repository = ContentRepository(
            remote: ContentRemoteDataSource(networkClient: session.authedClient)
        )
        return PostDetailContentClient(
            contentDetail: { id in try await repository.contentDetail(id: id) }
        )
    }
}
