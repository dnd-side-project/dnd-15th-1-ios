import ThirdParty

@DependencyClient
public struct OnboardingClient: Sendable {
    public var hasSeenAppIntro: @Sendable () async -> Bool = { false }
    public var markAppIntroSeen: @Sendable () async -> Void = { }
}

extension OnboardingClient: TestDependencyKey {
    public static let testValue = OnboardingClient()
}

public extension DependencyValues {
    var onboardingClient: OnboardingClient {
        get { self[OnboardingClient.self] }
        set { self[OnboardingClient.self] = newValue }
    }
}
