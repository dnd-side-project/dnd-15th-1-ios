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

    public func notificationSettings() async throws -> NotificationSettings {
        do {
            let dto = try await profileRemote.notificationSettings()
            return ProfileDTOMapper.toDomain(dto)
        } catch {
            throw ProfileErrorMapper.map(error)
        }
    }

    public func updateNotificationSettings(
        _ settings: NotificationSettings
    ) async throws -> NotificationSettings {
        do {
            let dto = try await profileRemote.updateNotificationSettings(
                ProfileDTOMapper.toRequest(settings)
            )
            return ProfileDTOMapper.toDomain(dto)
        } catch {
            throw ProfileErrorMapper.map(error)
        }
    }

    // 온보딩과 달리 초기화 분기 없이 곧장 PATCH 만 한다. 프로필 수정 화면용
    public func updateProfile(nickname: String, iconID: Int) async throws -> UserProfile {
        do {
            let updated = try await profileRemote.updateProfile(nickname: nickname, profileIcon: iconID)
            return ProfileDTOMapper.toDomain(updated, datePreference: nil)
        } catch {
            throw ProfileErrorMapper.map(error)
        }
    }

    public func updateNickname(nickname: String, iconID: Int) async throws -> UserProfile {
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

            let updated = try await profileRemote.updateProfile(
                nickname: nickname,
                profileIcon: iconID
            )
            // PATCH 응답에 성향이 없어서 방금 읽은 회원 정보의 값을 재사용한다.
            return ProfileDTOMapper.toDomain(
                updated,
                datePreference: ProfileDTOMapper.toDatePreference(member.datePreferences)
            )
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
}
