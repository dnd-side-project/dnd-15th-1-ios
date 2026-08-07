import Foundation

public enum SocialAuthError: Error, Sendable, Equatable {
    case cancelled
    case failed
    case notConfigured(message: String)
}
