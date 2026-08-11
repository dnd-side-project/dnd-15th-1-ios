import Foundation

public enum TermsType: String, Equatable, Sendable, Identifiable {
    case service
    case privacy

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .service: "이용약관"
        case .privacy: "개인정보수집 및 이용"
        }
    }

    public var url: URL? {
        switch self {
        case .service:
            URL(string: "https://dulpick.omong.jp/terms")
        case .privacy:
            URL(string: "https://dulpick.omong.jp/privacy")
        }
    }
}
