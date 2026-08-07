import Foundation

public enum AppInfo {
    public static var bundleID: String {
        Bundle.main.bundleIdentifier
            ?? Bundle.main.object(forInfoDictionaryKey: kCFBundleIdentifierKey as String) as? String
            ?? "unknown.bundle"
    }

    public static var displayName: String {
        if let value = nonEmptyString(fromInfoDictionaryKey: "CFBundleDisplayName") {
            return value
        }
        if let value = nonEmptyString(fromInfoDictionaryKey: "CFBundleName") {
            return value
        }
        return "Dulpick"
    }

    public static var productName: String {
        nonEmptyString(fromInfoDictionaryKey: "CFBundleName") ?? displayName
    }

    public static var apiBaseURL: URL {
        let raw = requiredString(.apiBaseURL)
        guard let url = URL(string: raw) else {
            preconditionFailure("Invalid API_BASE_URL in Info.plist: \(raw)")
        }
        return url
    }

    public static var kakaoNativeAppKey: String? {
        string(.kakaoNativeAppKey)
    }

    public static var googleClientID: String? {
        string(.googleClientID)
    }

    public static var googleReversedClientID: String? {
        string(.googleReversedClientID)
    }

    public static func string(_ key: InfoPlistKey) -> String? {
        nonEmptyString(fromInfoDictionaryKey: key.rawValue)
    }

    public static func requiredString(_ key: InfoPlistKey) -> String {
        guard let value = string(key) else {
            preconditionFailure("Missing Info.plist value for key: \(key.rawValue)")
        }
        return value
    }

    private static func nonEmptyString(fromInfoDictionaryKey key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
