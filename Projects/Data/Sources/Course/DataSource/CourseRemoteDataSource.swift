//
//  CourseRemoteDataSource.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import CoreNetwork
import Foundation

public struct CourseRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func create(_ request: CreateDateCourseRequestDTO) async throws -> DateCourseResponseDTO {
        try await networkClient.request(CourseEndpoint.create(request))
    }

    func placePool() async throws -> DateCoursePlacePoolResponseDTO {
        try await networkClient.request(CourseEndpoint.placePool)
    }
}
