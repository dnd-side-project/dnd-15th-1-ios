import CoreNetwork
import Foundation

enum NotificationEndpoint: APIEndpoint {
    case register(deviceID: String, body: NotificationDeviceRequestDTO)
    case unregister(deviceID: String)
    case settings
    case updateSettings(NotificationSettingsRequestDTO)

    var path: String {
        switch self {
        case let .register(deviceID, _):
            return "/api/v1/push-devices/\(deviceID)"
        case let .unregister(deviceID):
            return "/api/v1/push-devices/\(deviceID)"
        case .settings, .updateSettings:
            return "/api/v1/members/me/notification-settings"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .register, .updateSettings:
            return .put
        case .unregister:
            return .delete
        case .settings:
            return .get
        }
    }

    var body: Data? {
        let encoder = NetworkJSONCoding.makeEncoder()
        switch self {
        case let .register(_, request):
            return try? encoder.encode(request)
        case let .updateSettings(request):
            return try? encoder.encode(request)
        case .unregister, .settings:
            return nil
        }
    }
}
