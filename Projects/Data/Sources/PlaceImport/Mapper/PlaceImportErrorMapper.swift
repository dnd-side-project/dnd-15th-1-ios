//
//  PlaceImportErrorMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Domain
import Foundation

enum PlaceImportErrorMapper {
    static func map(_ error: Error) -> PlaceImportError {
        if let placeImportError = error as? PlaceImportError {
            return placeImportError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    private static func mapNetworkError(_ error: NetworkError) -> PlaceImportError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .notFound:
            return .notFound
        case let .clientError(statusCode, _):
            return statusCode == tooManyRequestsStatusCode ? .rateLimited : .unknown
        case .badRequest, .conflict, .serverError,
             .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }

    private static let tooManyRequestsStatusCode = 429
}
