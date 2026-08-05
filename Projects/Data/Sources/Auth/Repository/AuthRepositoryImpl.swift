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

    public func currentUser() async throws -> AuthUser? {
        do {
            return try await authLocal.loadSession()?.toDomain
        } catch {
            throw mapToDomainError(error)
        }
    }

    public func signIn() async throws -> AuthUser {
        do {
            let session = try await authRemote.signIn()
            try await authLocal.saveSession(session)
            return session.toDomain
        } catch {
            throw mapToDomainError(error)
        }
    }

    public func signOut() async throws {
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
            return .storageFailed
        }
        if error is DecodingError {
            return .decodingFailed
        }
        return .unknown
    }
}
