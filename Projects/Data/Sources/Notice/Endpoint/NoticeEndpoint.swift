import CoreNetwork
import Foundation

enum NoticeEndpoint: APIEndpoint {
    case notices(page: Int, size: Int)

    var path: String {
        switch self {
        case .notices:
            return "/api/v1/notices"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .notices:
            return .get
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case let .notices(page, size):
            return [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size)),
            ]
        }
    }
}
