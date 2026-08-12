import Domain
import Foundation

public enum ProfileClientFactory {
    public static func make(session: AuthSessionAssembly) -> ProfileClient {
        makeClient(repository: makeRepo(session: session))
    }

    private static func makeClient(repository: ProfileRepository) -> ProfileClient {
        ProfileClient(
            updateNickname: { nickname, iconID in
                try await repository.updateNickname(nickname: nickname, iconID: iconID)
            },
            updateDatePreference: { preference in
                try await repository.updateDatePreference(preference)
            }
        )
    }

    private static func makeRepo(session: AuthSessionAssembly) -> ProfileRepository {
        ProfileRepository(
            profileRemote: ProfileRemoteDataSource(networkClient: session.authedClient)
        )
    }
}
