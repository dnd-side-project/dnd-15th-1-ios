import Feature
import ThirdParty
import XCTest

@MainActor
final class AppIntroFeatureTests: XCTestCase {
    func test_다음_0에서_1로_이동() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 0)) {
            AppIntroFeature()
        }
        await store.send(.nextButtonTapped) {
            $0.pageIndex = 1
        }
    }

    func test_다음_1에서_2로_이동() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 1)) {
            AppIntroFeature()
        }
        await store.send(.nextButtonTapped) {
            $0.pageIndex = 2
        }
    }

    func test_마지막_다음_완료델리게이트_전달() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 2)) {
            AppIntroFeature()
        }
        await store.send(.nextButtonTapped) {
            $0.hasCompleted = true
        }
        await store.receive(\.delegate.completed)
    }

    func test_마지막_다음_완료는_한번만() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 2)) {
            AppIntroFeature()
        }
        await store.send(.nextButtonTapped) {
            $0.hasCompleted = true
        }
        await store.receive(\.delegate.completed)
        await store.send(.nextButtonTapped)
    }

    func test_뒤로_2에서_1로_이동() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 2)) {
            AppIntroFeature()
        }
        await store.send(.backButtonTapped) {
            $0.pageIndex = 1
        }
    }

    func test_뒤로_1에서_0으로_이동() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 1)) {
            AppIntroFeature()
        }
        await store.send(.backButtonTapped) {
            $0.pageIndex = 0
        }
    }

    func test_첫페이지_뒤로는_무시() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 0)) {
            AppIntroFeature()
        }
        await store.send(.backButtonTapped)
    }

    func test_초기화시_pageIndex_클램프() {
        XCTAssertEqual(AppIntroFeature.State(pageIndex: -1).pageIndex, 0)
        XCTAssertEqual(AppIntroFeature.State(pageIndex: 99).pageIndex, 2)
        XCTAssertEqual(AppIntroFeature.State(pageIndex: 1).pageIndex, 1)
        XCTAssertFalse(AppIntroFeature.State().hasCompleted)
    }

    func test_페이지변경_pageIndex_갱신() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 0)) {
            AppIntroFeature()
        }
        await store.send(.pageChanged(1)) {
            $0.pageIndex = 1
        }
        await store.send(.pageChanged(2)) {
            $0.pageIndex = 2
        }
    }

    func test_페이지변경_동일인덱스는_무시() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 1)) {
            AppIntroFeature()
        }
        await store.send(.pageChanged(1))
    }

    func test_페이지변경_범위밖_클램프() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 1)) {
            AppIntroFeature()
        }
        await store.send(.pageChanged(-1)) {
            $0.pageIndex = 0
        }
        await store.send(.pageChanged(99)) {
            $0.pageIndex = 2
        }
    }

    func test_페이지변경은_완료를_만들지_않음() async {
        let store = TestStore(initialState: AppIntroFeature.State(pageIndex: 2)) {
            AppIntroFeature()
        }
        await store.send(.pageChanged(2))
        await store.send(.pageChanged(1)) {
            $0.pageIndex = 1
        }
    }
}
