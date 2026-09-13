@testable import Feature
import ThirdParty
import XCTest

@MainActor
final class MainTabFeatureTests: XCTestCase {
    func test_탭을_누르면_그_탭의_이벤트를_보낸다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.tabSelected(.explore)) {
            $0.selectedTab = .explore
        }
        await store.send(.tabSelected(.map)) {
            $0.selectedTab = .map
        }
        await store.send(.tabSelected(.myPage)) {
            $0.selectedTab = .myPage
        }
        await store.finish()
        XCTAssertEqual(sent.value, [.exploreViewed, .mapViewed, .myPageViewed])
    }

    func test_홈_탭에는_이벤트가_없다() async {
        let sent = LockIsolated<[AnalyticsEvent]>([])
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        } withDependencies: {
            $0.analyticsClient.track = { event in sent.withValue { $0.append(event) } }
        }

        await store.send(.tabSelected(.home))
        await store.finish()
        XCTAssertTrue(sent.value.isEmpty)
    }
}
