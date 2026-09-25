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
    /// 공유로 받은 링크의 장소 가져오기를 시작한다
    public var start: @Sendable (_ sourceURL: URL) async throws -> PlaceImport
    public var poll: @Sendable (_ importID: String) async throws -> PlaceImport
    /// 고른 후보를 저장한다
    public var confirm: @Sendable (_ importID: String, _ candidateIDs: [String]) async throws -> Void
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
