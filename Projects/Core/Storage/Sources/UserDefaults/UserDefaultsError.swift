import Foundation

public enum UserDefaultsError: Error, Equatable, Sendable {
    case encodingFailed
    case decodingFailed
}
