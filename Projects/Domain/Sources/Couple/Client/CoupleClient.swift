import Foundation
import ThirdParty

@DependencyClient
public struct CoupleClient: Sendable {
    public var inviteCode: @Sendable () async throws -> InviteCode
    public var previewPartner: @Sendable (_ inviteCode: String) async throws -> PartnerPreview
    public var connect: @Sendable (_ inviteCode: String) async throws -> Couple
    public var current: @Sendable () async throws -> Couple?
}

extension CoupleClient: TestDependencyKey {
    public static let testValue = CoupleClient()
}

public extension DependencyValues {
    var coupleClient: CoupleClient {
        get { self[CoupleClient.self] }
        set { self[CoupleClient.self] = newValue }
    }
}
