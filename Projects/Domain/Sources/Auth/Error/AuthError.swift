import Foundation

public enum AuthError: Error, Equatable, Sendable {
    case invalidCredentials
    case sessionExpired
    case networkUnavailable
    case storageFailed
    case decodingFailed
    case unknown
}
