//
//  HomeClient.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Foundation
import ThirdParty

@DependencyClient
public struct HomeClient: Sendable {
    public var home: @Sendable () async throws -> HomeSummary
    public var recentSavedPlaces: @Sendable (_ size: Int) async throws -> [SavedPlace]
}

extension HomeClient: TestDependencyKey {
    public static let testValue = HomeClient()
    public static let previewValue = HomeClient.mock
}

public extension DependencyValues {
    var homeClient: HomeClient {
        get { self[HomeClient.self] }
        set { self[HomeClient.self] = newValue }
    }
}
