//
//  ContentErrorMapper.swift
//  Dulpick
//
//  Created by 이인호 on 8/17/26.
//

import CoreNetwork
import Domain
import Foundation

enum ContentErrorMapper {
    static func map(_ error: Error) -> ContentError {
        if let contentError = error as? ContentError {
            return contentError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    private static func mapNetworkError(_ error: NetworkError) -> ContentError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .notFound:
            return .notFound
        case .badRequest, .forbidden, .conflict, .clientError, .serverError,
             .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }
}
