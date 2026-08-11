import Foundation
import ThirdParty

@DependencyClient
public struct ProfileClient: Sendable {
    public var updateNickname: @Sendable (_ nickname: String, _ iconID: Int) async throws -> UserProfile
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
