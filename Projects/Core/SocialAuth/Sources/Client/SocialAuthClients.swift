import Foundation

public struct SocialAuthClients: Sendable {
    public let kakao: any SocialAuthClient
    public let apple: any SocialAuthClient
    public let google: any SocialAuthClient

    public init(
        kakao: any SocialAuthClient,
        apple: any SocialAuthClient,
        google: any SocialAuthClient
    ) {
        self.kakao = kakao
        self.apple = apple
        self.google = google
    }
}
