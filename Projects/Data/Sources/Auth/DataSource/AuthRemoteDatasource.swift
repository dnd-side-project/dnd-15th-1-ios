import CoreNetwork
import Domain
import Foundation

public struct AuthRemoteDataSource: Sendable {
    private let plainClient: any NetworkClient
    private let authedClient: any NetworkClient

    public init(
        plainClient: any NetworkClient,
        authedClient: any NetworkClient
    ) {
        self.plainClient = plainClient
        self.authedClient = authedClient
    }

    public init(networkClient: any NetworkClient) {
        self.init(plainClient: networkClient, authedClient: networkClient)
    }

    func issueNonce(provider: AuthProvider) async throws -> AuthNonceDTO {
        try await plainClient.request(
            AuthEndpoint.issueNonce(provider: provider)
        )
    }

    func socialLogin(
        provider: AuthProvider,
        idToken: String,
        authorizationCode: String?,
        nonce: String
    ) async throws -> SocialLoginResponseDTO {
        try await plainClient.request(
            AuthEndpoint.socialLogin(
                provider: provider,
                idToken: idToken,
                authorizationCode: authorizationCode,
                nonce: nonce
            )
        )
    }

    func reissue(refreshToken: String) async throws -> AuthTokenDTO {
        try await plainClient.request(
            AuthEndpoint.reissue(refreshToken: refreshToken)
        )
    }

    func logout(refreshToken: String) async throws {
        try await authedClient.request(
            AuthEndpoint.logout(refreshToken: refreshToken)
        )
    }
}
