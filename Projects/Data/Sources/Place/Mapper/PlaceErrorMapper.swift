//
//  PlaceErrorMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Domain
import Foundation

enum PlaceErrorMapper {
    static func map(_ error: Error) -> PlaceError {
        if let placeError = error as? PlaceError {
            return placeError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    private static func mapNetworkError(_ error: NetworkError) -> PlaceError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .notFound:
            return .notFound
        case .conflict:
            return .alreadySaved
        case .badRequest, .forbidden, .clientError, .serverError,
             .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }
}
