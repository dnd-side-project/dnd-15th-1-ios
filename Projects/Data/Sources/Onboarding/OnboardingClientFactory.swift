import CoreStorage
import Domain
import Foundation

public enum OnboardingClientFactory {
    private static let hasSeenAppIntroKey = "onboarding.hasSeenAppIntro"

    public static func make(userDefaults: any UserDefaultsStorage) -> OnboardingClient {
        OnboardingClient(
            hasSeenAppIntro: {
                await loadHasSeen(userDefaults)
            },
            markAppIntroSeen: {
                await saveHasSeen(true, to: userDefaults)
            }
        )
    }

    private static func loadHasSeen(_ storage: any UserDefaultsStorage) async -> Bool {
        let value: Bool? = try? await storage.get(forKey: hasSeenAppIntroKey)
        return value ?? false
    }

    private static func saveHasSeen(_ value: Bool, to storage: any UserDefaultsStorage) async {
        try? await storage.save(value, forKey: hasSeenAppIntroKey)
    }
}
