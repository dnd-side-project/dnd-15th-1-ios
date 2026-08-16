public enum LogCategory: String, Sendable {
    case app
    case network
    case storage
    case auth
    case feature
    case data

    /// 콘솔 접두사는 Title Case 사용 (`App`, `Network`, `Feature`).
    public var displayName: String {
        switch self {
        case .app, .network, .storage, .auth, .feature, .data:
            return rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}
