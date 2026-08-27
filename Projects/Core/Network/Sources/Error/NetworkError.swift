import Foundation

public enum NetworkError: Error, Equatable, Sendable {
    /// URL/path 조합이 잘못됨
    case invalidURL
    /// HTTP 응답이 아니거나 응답 형식이 비정상
    case invalidResponse
    /// 응답 body JSON 디코딩 실패
    case decodingFailed
    /// 400 Bad Request
    case badRequest(message: String?)
    /// 401 Unauthorized. refresh 실패/불가 포함
    case unauthorized
    /// 403 Forbidden
    case forbidden(message: String?)
    /// 404 Not Found
    case notFound(message: String?)
    /// 409 Conflict
    case conflict(message: String?)
    /// 그 외 4xx
    case clientError(statusCode: Int, message: String?)
    /// 5xx 또는 알 수 없는 서버 오류
    case serverError(statusCode: Int, message: String?)
    /// 연결 실패/타임아웃 등 transport 오류
    case transport(message: String)
}

extension NetworkError: CustomNSError {
    public static var errorDomain: String { "CoreNetwork.NetworkError" }

    public var errorCode: Int {
        switch self {
        case .invalidURL: return 1
        case .invalidResponse: return 2
        case .decodingFailed: return 3
        case .badRequest: return 4
        case .unauthorized: return 5
        case .forbidden: return 6
        case .notFound: return 7
        case .conflict: return 8
        case .clientError: return 9
        case .serverError: return 10
        case .transport: return 11
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [NSLocalizedDescriptionKey: String(describing: self)]
        switch self {
        case let .badRequest(message),
             let .forbidden(message),
             let .notFound(message),
             let .conflict(message):
            if let message {
                info["message"] = message
            }
        case let .clientError(statusCode, message),
             let .serverError(statusCode, message):
            info["statusCode"] = statusCode
            if let message {
                info["message"] = message
            }
        case let .transport(message):
            info["message"] = message
        default:
            break
        }
        return info
    }

    static func fromNSError(_ error: NSError) -> NetworkError? {
        guard error.domain == errorDomain else { return nil }
        let message = error.userInfo["message"] as? String
        let status = error.userInfo["statusCode"] as? Int
        let mapping: [Int: NetworkError] = [
            1: .invalidURL,
            2: .invalidResponse,
            3: .decodingFailed,
            4: .badRequest(message: message),
            5: .unauthorized,
            6: .forbidden(message: message),
            7: .notFound(message: message),
            8: .conflict(message: message),
            9: .clientError(statusCode: status ?? 400, message: message),
            10: .serverError(statusCode: status ?? 500, message: message),
            11: .transport(message: message ?? error.localizedDescription),
        ]
        return mapping[error.code]
    }
}
