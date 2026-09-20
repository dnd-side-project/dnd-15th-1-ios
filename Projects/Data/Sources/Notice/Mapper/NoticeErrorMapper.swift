import CoreNetwork
import Domain
import Foundation

enum NoticeErrorMapper {
    static func map(_ error: Error) -> NoticeError {
        if let noticeError = error as? NoticeError {
            return noticeError
        }
        if let networkError = error as? NetworkError {
            return mapNetworkError(networkError)
        }
        return .unknown
    }

    private static func mapNetworkError(_ error: NetworkError) -> NoticeError {
        switch error {
        case .transport:
            return .network
        case .unauthorized, .badRequest, .forbidden, .notFound, .conflict,
             .clientError, .serverError, .decodingFailed, .invalidResponse, .invalidURL:
            return .unknown
        }
    }
}
