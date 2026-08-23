import CoreNetwork
import Foundation

enum PushEndpoint: APIEndpoint {
    case register(deviceID: String, body: PushDeviceRequestDTO)
    case unregister(deviceID: String)

    var path: String {
        switch self {
        case let .register(deviceID, _):
            return "/api/v1/push-devices/\(deviceID)"
        case let .unregister(deviceID):
            return "/api/v1/push-devices/\(deviceID)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register:
            return .put
        case .unregister:
            return .delete
        }
    }

    var body: Data? {
        let encoder = NetworkJSONCoding.makeEncoder()
        switch self {
        case let .register(_, request):
            return try? encoder.encode(request)
        case .unregister:
            return nil
        }
    }
}
