//
//  HomeClientFactory.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import Foundation

public enum HomeClientFactory {
    public static func make(session: AuthSessionAssembly) -> HomeClient {
        let repository = HomeRepository(
            remote: HomeRemoteDataSource(networkClient: session.authedClient)
        )
        return HomeClient(
            home: { try await repository.home() },
            recentSavedPlaces: { size in try await repository.recentSavedPlaces(size: size) },
            pastDates: { size in try await repository.pastDates(size: size) },
            pastCourses: { size in try await repository.pastCourses(size: size) }
        )
    }
}
