import Foundation

public enum KeychainError: Error, Equatable, Sendable {
    case encodingFailed
    case decodingFailed
    case itemNotFound
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)
}
