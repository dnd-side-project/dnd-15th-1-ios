import CoreNetwork
import Foundation

enum CoupleEndpoint: APIEndpoint {
    case connectionCode
    case connect(connectionCode: String)
    case current
    case disconnect

    var path: String {
        switch self {
        case .connectionCode:
            return "/api/v1/connection-codes/me"
        case .connect:
            return "/api/v1/couples"
        case .current, .disconnect:
            return "/api/v1/couples/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .connectionCode, .current:
            return .get
        case .connect:
            return .post
        case .disconnect:
            return .delete
        }
    }

    var headers: [String: String] {
        [:]
    }

    var body: Data? {
        let encoder = NetworkJSONCoding.makeEncoder()
        switch self {
        case .connectionCode, .current, .disconnect:
            return nil
        case let .connect(connectionCode):
            return try? encoder.encode(
                CoupleDTOMapper.toRequest(inviteCode: connectionCode)
            )
        }
    }
}
