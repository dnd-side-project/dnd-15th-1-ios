import CoreStorage
import Domain
import Foundation

public struct AuthRepositoryImpl: Sendable {
    private let authRemote: AuthRemoteDatasource
    private let authLocal: AuthLocalDatasource

    public init(
        authRemote: AuthRemoteDatasource,
        authLocal: AuthLocalDatasource
    ) {
        self.authRemote = authRemote
        self.authLocal = authLocal
    }

    public func restoreSession() async throws -> AuthSession? {
        do {
            return try await authLocal.loadSession()?.toDomain
        } catch {
            throw mapToDomainError(error)
        }
    }

    public func currentSession() async throws -> AuthSession? {
        try await restoreSession()
    }

    public func login(provider: AuthProvider) async throws -> AuthSession {
        do {
            let session = try await authRemote.login(provider: provider)
            try await authLocal.saveSession(session)
            return session.toDomain
        } catch {
            throw mapToDomainError(error)
        }
    }

    public func logout() async throws {
        do {
            try await authLocal.saveSession(nil)
        } catch {
            throw mapToDomainError(error)
        }
    }
}

private extension AuthRepositoryImpl {
    func mapToDomainError(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }
        if error is KeychainError {
            return .storage
        }
        if error is DecodingError {
            return .unknown
        }
        return .unknown
    }
}
