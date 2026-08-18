import Feature
import ThirdParty
import XCTest

@MainActor
final class MainTabMapDelegateTests: XCTestCase {
    func test_받는_쪽이_없는_신호는_상위로_새어보내지_않는다() async {
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // 받는 쪽은 Cycle 2~4 다. 지금은 상태를 안 바꾸고 조용히 삼킨다
        await store.send(.map(.delegate(.placeSelected("7"))))
        await store.send(.map(.delegate(.searchRequested)))
        await store.send(.map(.delegate(.courseRequested)))
        await store.send(.map(.delegate(.editRequested("7"))))
        await store.send(.map(.delegate(.deleteRequested("7"))))

        XCTAssertEqual(store.state.selectedTab, .home)
    }

    func test_세션_만료만_상위로_올린다() async {
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // 전역 에러라 RootFlow 까지 올라가야 로그인으로 되돌아간다
        await store.send(.map(.delegate(.sessionExpired)))
        await store.receive(\.delegate.sessionExpired)
    }
}
