//
//  PlaceImportClient.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import Foundation
import ThirdParty

@DependencyClient
public struct PlaceImportClient: Sendable {
    public var start: @Sendable (_ sourceUrl: String) async throws -> PlaceImport
    public var poll: @Sendable (_ importId: Int) async throws -> PlaceImport
    public var confirm: @Sendable (_ importId: Int, _ candidateIDs: [Int]) async throws -> Void
}

extension PlaceImportClient: TestDependencyKey {
    public static let testValue = PlaceImportClient()
}

public extension DependencyValues {
    var placeImportClient: PlaceImportClient {
        get { self[PlaceImportClient.self] }
        set { self[PlaceImportClient.self] = newValue }
    }
}
