import Domain
import Foundation

public struct ProfileRepository: Sendable {
    private let profileRemote: ProfileRemoteDataSource

    public init(profileRemote: ProfileRemoteDataSource) {
        self.profileRemote = profileRemote
    }

    public func member() async throws -> UserProfile {
        do {
            let member = try await profileRemote.member()
            guard let profile = ProfileDTOMapper.toDomain(member) else {
                throw ProfileError.unknown
            }
            return profile
        } catch {
            throw ProfileErrorMapper.map(error)
        }
    }

    public func withdraw() async throws {
        do {
            try await profileRemote.withdraw()
        } catch {
            throw ProfileErrorMapper.map(error)
        }
    }

    // 온보딩과 달리 초기화 분기 없이 곧장 PATCH 한다. 프로필 수정 화면용.
    public func updateProfile(nickname: String, iconID: Int) async throws -> UserProfile {
        do {
            let member = try await profileRemote.member()
            return try await patchProfile(nickname: nickname, iconID: iconID, member: member)
        } catch {
            throw ProfileErrorMapper.map(error)
        }
    }

    /// 온보딩 닉네임 단계. 프로필이 없으면 만들고, 이미 있으면 고친다
    public func setUpProfile(nickname: String, iconID: Int) async throws -> UserProfile {
        do {
            let member = try await profileRemote.member()

            guard member.onboardingCompleted else {
                let initialized = try await profileRemote.initializeProfile(
                    nickname: nickname,
                    profileIcon: iconID,
                    datePreferences: nil
                )
                return ProfileDTOMapper.toDomain(initialized)
            }

            return try await patchProfile(nickname: nickname, iconID: iconID, member: member)
        } catch {
            throw ProfileErrorMapper.map(error)
        }
    }

    public func updateDatePreference(_ preference: DatePreference) async throws -> UserProfile {
        do {
            try await profileRemote.updateDatePreferences(
                ProfileDTOMapper.toRequest(preference)
            )
            let member = try await profileRemote.member()
            guard let profile = ProfileDTOMapper.toDomain(member) else {
                throw ProfileError.unknown
            }
            return profile
        } catch {
            throw ProfileErrorMapper.map(error)
        }
    }

    // PATCH 응답엔 성향이 없어 방금 읽은 회원 정보의 성향을 재사용한다
    private func patchProfile(
        nickname: String,
        iconID: Int,
        member: MemberResponseDTO
    ) async throws -> UserProfile {
        let updated = try await profileRemote.updateProfile(nickname: nickname, profileIcon: iconID)
        return ProfileDTOMapper.toDomain(
            updated,
            datePreference: ProfileDTOMapper.toDatePreference(member.datePreferences)
        )
    }
}
