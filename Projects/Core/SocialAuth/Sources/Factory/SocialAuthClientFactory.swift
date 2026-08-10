import Foundation

public struct SocialAuthClientFactory: Sendable {
    public init() {}

    @MainActor
    public func make() -> SocialAuthClients {
        SocialAuthClients(
            kakao: KakaoSocialAuthClient(),
            apple: AppleSocialAuthClient(),
            google: GoogleSocialAuthClient()
        )
    }
}
