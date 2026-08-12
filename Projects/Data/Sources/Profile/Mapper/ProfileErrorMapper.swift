import CoreNetwork
import Domain
import Foundation

enum ProfileErrorMapper {
    static func mapNetworkError(_ error: NetworkError) -> ProfileError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .badRequest, .conflict:
            return .invalidNickname
        case let .clientError(statusCode, _):
            return statusCode == unprocessableContentStatusCode ? .invalidNickname : .unknown
        case .forbidden, .notFound, .serverError:
            return .unknown
        case .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }

    static func map(_ error: Error) -> ProfileError {
        if let profileError = error as? ProfileError {
            return profileError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    private static let unprocessableContentStatusCode = 422
}
