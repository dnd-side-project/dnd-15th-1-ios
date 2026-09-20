import Foundation
import ThirdParty

@DependencyClient
public struct ProfileClient: Sendable {
    public var member: @Sendable () async throws -> UserProfile
    public var withdraw: @Sendable () async throws -> Void
    public var updateProfile: @Sendable (_ nickname: String, _ iconID: Int) async throws -> UserProfile
    /// 온보딩 닉네임 단계. 프로필이 없으면 만들고, 이미 있으면 고친다
    public var setUpProfile: @Sendable (_ nickname: String, _ iconID: Int) async throws -> UserProfile
    public var updateDatePreference: @Sendable (_ preference: DatePreference) async throws -> UserProfile
}

extension ProfileClient: TestDependencyKey {
    public static let testValue = ProfileClient()
}

public extension DependencyValues {
    var profileClient: ProfileClient {
        get { self[ProfileClient.self] }
        set { self[ProfileClient.self] = newValue }
    }
}
