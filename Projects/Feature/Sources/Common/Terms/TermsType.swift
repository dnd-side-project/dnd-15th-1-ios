import Foundation

public enum TermsType: String, Equatable, Sendable, Identifiable, CaseIterable {
    case service
    case privacy
    case marketing

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .service: "이용약관"
        case .privacy: "개인정보수집 및 이용"
        case .marketing: "마케팅 수신 동의"
        }
    }

    /// 동의가 필수인 약관인지. 온보딩 시트의 버튼 문구를 정하는 데만 쓴다
    public var isRequired: Bool {
        switch self {
        case .service, .privacy: true
        case .marketing: false
        }
    }

    public var url: URL? {
        switch self {
        case .service:
            URL(string: "https://dulpick.omong.kr/terms")
        case .privacy:
            URL(string: "https://dulpick.omong.kr/privacy")
        case .marketing:
            URL(string: "https://dulpick.omong.kr/marketing")
        }
    }
}
