import Feature
import ThirdParty
import XCTest

@MainActor
final class MainTabMapDelegateTests: XCTestCase {
    func test_지도_화면_이동은_상위로_새어보내지_않는다() async {
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // 화면 이동은 MapFlowFeature 가 자기 path 로 삼킨다. MainTab 은 탭만 지킨다
        // 장소 상세는 지도 위 시트라 경로를 안 쌓는다
        await store.send(.map(.map(.delegate(.placeDetailRequested("7")))))
        XCTAssertEqual(store.state.map.path, [])
        await store.send(.map(.map(.delegate(.searchRequested)))) {
            $0.map.path = [.search]
            $0.map.placeSearch = PlaceSearchFeature.State()
        }
        await store.send(.map(.map(.delegate(.courseRequested)))) {
            $0.map.course = CourseFeature.State()
            $0.map.path = [.search, .course]
        }
        await store.send(.map(.map(.delegate(.aliasRequested("7")))))
        await store.send(.map(.map(.delegate(.deleteRequested("7")))))

        XCTAssertEqual(store.state.selectedTab, .home)
    }

    func test_세션_만료만_상위로_올린다() async {
        let store = TestStore(initialState: MainTabFeature.State()) {
            MainTabFeature()
        }

        // 전역 에러라 RootFlow 까지 올라가야 로그인으로 되돌아간다
        await store.send(.map(.map(.delegate(.sessionExpired))))
        await store.receive(\.map.delegate.sessionExpired)
        await store.receive(\.delegate.sessionExpired)
    }
}
