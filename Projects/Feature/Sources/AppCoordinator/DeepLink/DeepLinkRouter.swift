import Foundation

public enum DeepLinkRouter {
    public static func parse(_ url: URL) -> DeepLinkRoute? {
        let host = url.host?.lowercased()
        let pathParts = url.path
            .split(separator: "/")
            .map(String.init)
        let firstPath = pathParts.first?.lowercased()

        if host == "home" || firstPath == "home" { return .home }
        if host == "explore" || firstPath == "explore" { return .explore }
        if host == "map" || firstPath == "map" { return .map }
        if host == "mypage"
            || host == "my-page"
            || firstPath == "mypage"
            || firstPath == "my-page"
        {
            return .myPage
        }
        if host == "profile" || firstPath == "profile" {
            return .myPage
        }
        if host == "auth" || firstPath == "auth" {
            let action: String?
            if host == "auth" {
                action = pathParts.first?.lowercased()
            } else {
                action = pathParts.dropFirst().first?.lowercased()
            }
            if action == "sign-in" || action == nil {
                return .signIn
            }
        }
        if host == "sign-in" {
            return .signIn
        }
        return nil
    }
}
