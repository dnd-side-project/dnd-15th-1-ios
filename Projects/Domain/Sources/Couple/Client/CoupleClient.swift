import Foundation
import ThirdParty

@DependencyClient
public struct CoupleClient: Sendable {
    public var inviteCode: @Sendable () async throws -> InviteCode
    /// 연결된 상대를 돌려준다
    public var connect: @Sendable (_ inviteCode: String) async throws -> CoupleMember
    public var current: @Sendable () async throws -> CoupleStatus
    public var disconnect: @Sendable () async throws -> Void
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
