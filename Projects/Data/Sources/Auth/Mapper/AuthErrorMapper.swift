import CoreNetwork
import CoreSocialAuth
import CoreStorage
import Domain
import Foundation

enum AuthErrorMapper {
    static func mapSocialAuthError(_ error: SocialAuthError) -> AuthError {
        switch error {
        case .cancelled:
            return .cancelled
        case .failed:
            return .loginFailed
        }
    }

    static func mapNetworkError(_ error: NetworkError, isLoginPath: Bool) -> AuthError {
        switch error {
        case .transport:
            return .network
        case .unauthorized:
            return .unauthorized
        case .badRequest, .forbidden, .notFound, .conflict, .clientError, .serverError:
            return isLoginPath ? .loginFailed : .unknown
        case .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }

    static func map(_ error: Error, isLoginPath: Bool = false) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }
        if let socialAuthError = error as? SocialAuthError {
            return mapSocialAuthError(socialAuthError)
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError, isLoginPath: isLoginPath)
        }
        if error is KeychainError {
            return .storage
        }
        if error is DecodingError {
            return .unknown
        }
        return .unknown
    }
}
