import Foundation

struct PushDeviceRequestDTO: Encodable, Sendable, Equatable {
    let platform: String
    let provider: String
    let providerRegistrationId: String
    /// 없으면 키 자체가 실리지 않는다.
    let appVersion: String?
}
