import Foundation

public struct SocialAuthServices: Sendable {
    public let kakao: any SocialAuthService
    public let apple: any SocialAuthService
    public let google: any SocialAuthService

    public init(
        kakao: any SocialAuthService,
        apple: any SocialAuthService,
        google: any SocialAuthService
    ) {
        self.kakao = kakao
        self.apple = apple
        self.google = google
    }
}
