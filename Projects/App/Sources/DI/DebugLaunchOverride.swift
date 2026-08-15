#if DEBUG
import Domain
import Foundation
import ThirdParty

enum DebugLaunchOverride {
    static let forceAppIntroArgument = "-forceAppIntro"
    static let forceOnboardingArgument = "-forceOnboarding"

    static func apply(to values: inout DependencyValues) {
        if isEnabled(forceAppIntroArgument) {
            // 앱 인트로는 한 번 보면 로컬 플래그 때문에 다시 안 뜬다. 시뮬레이터 재확인용 무시 스위치
            values.onboardingClient.hasSeenAppIntro = { false }
        }

        if isEnabled(forceOnboardingArgument) {
            // 온보딩 완료 여부는 서버 값이라 앱에서 되돌릴 수 없다. 시뮬레이터 재확인용 무시 스위치
            values.authClient = forcingOnboarding(values.authClient)
        }
    }

    private static func isEnabled(_ argument: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    private static func forcingOnboarding(_ client: AuthClient) -> AuthClient {
        var forced = client
        forced.restoreSession = {
            try await client.restoreSession().map(incompleteOnboarding)
        }
        forced.login = { provider in
            incompleteOnboarding(try await client.login(provider))
        }
        return forced
    }

    private static func incompleteOnboarding(_ bootstrap: AuthBootstrap) -> AuthBootstrap {
        AuthBootstrap(
            session: bootstrap.session,
            isOnboardingCompleted: false
        )
    }
}
#endif
