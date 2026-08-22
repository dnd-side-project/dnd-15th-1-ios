//
//  HomeErrorMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import CoreNetwork
import Domain
import Foundation

enum HomeErrorMapper {
    static func map(_ error: Error) -> HomeError {
        if let homeError = error as? HomeError {
            return homeError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    private static func mapNetworkError(_ error: NetworkError) -> HomeError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .badRequest, .forbidden, .notFound, .conflict, .clientError, .serverError,
             .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }
}
