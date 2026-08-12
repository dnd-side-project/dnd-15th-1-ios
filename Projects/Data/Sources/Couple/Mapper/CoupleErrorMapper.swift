import CoreNetwork
import Domain
import Foundation

enum CoupleErrorMapper {
    static func mapNetworkError(_ error: NetworkError) -> CoupleError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .badRequest, .notFound:
            return .invalidInviteCode
        case .conflict:
            return .alreadyConnected
        case let .clientError(statusCode, _):
            switch statusCode {
            case unprocessableContentStatusCode:
                return .invalidInviteCode
            case tooManyRequestsStatusCode:
                return .rateLimited
            default:
                return .unknown
            }
        case .forbidden, .serverError:
            return .unknown
        case .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }

    static func map(_ error: Error) -> CoupleError {
        if let coupleError = error as? CoupleError {
            return coupleError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    private static let unprocessableContentStatusCode = 422
    private static let tooManyRequestsStatusCode = 429
}
