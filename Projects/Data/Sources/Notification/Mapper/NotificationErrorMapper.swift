import CoreNetwork
import Domain
import Foundation

enum NotificationErrorMapper {
    static func map(_ error: Error) -> NotificationError {
        if let notificationError = error as? NotificationError {
            return notificationError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    static func mapNetworkError(_ error: NetworkError) -> NotificationError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .badRequest:
            return .invalidRequest
        case .conflict:
            return .registrationConflict
        case let .serverError(statusCode, _):
            return statusCode == serviceUnavailableStatusCode ? .providerUnavailable : .unknown
        case .forbidden, .notFound, .clientError:
            return .unknown
        case .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }

    private static let serviceUnavailableStatusCode = 503
}
