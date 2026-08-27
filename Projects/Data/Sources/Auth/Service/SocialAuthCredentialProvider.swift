import CoreSocialAuth
import Domain
import Foundation

public struct SocialAuthCredentialProvider: Sendable {
    private let clients: SocialAuthClients

    public init(clients: SocialAuthClients) {
        self.clients = clients
    }

    func login(provider: AuthProvider, nonce: String) async throws -> SocialAuthCredential {
        do {
            return try await client(for: provider).login(nonce: nonce)
        } catch let error as SocialAuthError {
            throw AuthErrorMapper.mapSocialAuthError(error)
        } catch {
            throw AuthError.unknown
        }
    }

    private func client(for provider: AuthProvider) -> any SocialAuthClient {
        switch provider {
        case .kakao:
            return clients.kakao
        case .apple:
            return clients.apple
        case .google:
            return clients.google
        }
    }
}
