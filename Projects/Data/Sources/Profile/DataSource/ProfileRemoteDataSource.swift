import CoreNetwork
import Foundation

public struct ProfileRemoteDataSource: Sendable {
    private let networkClient: any NetworkClient

    public init(networkClient: any NetworkClient) {
        self.networkClient = networkClient
    }

    func member() async throws -> MemberResponseDTO {
        try await networkClient.request(ProfileEndpoint.member)
    }

    func initializeProfile(
        nickname: String,
        profileIcon: Int,
        datePreferences: DatePreferencesRequestDTO?
    ) async throws -> InitializedMemberProfileResponseDTO {
        try await networkClient.request(
            ProfileEndpoint.initializeProfile(
                nickname: nickname,
                profileIcon: profileIcon,
                datePreferences: datePreferences
            )
        )
    }

    func updateProfile(
        nickname: String,
        profileIcon: Int
    ) async throws -> UpdatedMemberProfileResponseDTO {
        try await networkClient.request(
            ProfileEndpoint.updateProfile(
                nickname: nickname,
                profileIcon: profileIcon
            )
        )
    }

    func updateDatePreferences(_ preferences: DatePreferencesRequestDTO) async throws {
        try await networkClient.request(
            ProfileEndpoint.updateDatePreferences(preferences)
        )
    }
}
