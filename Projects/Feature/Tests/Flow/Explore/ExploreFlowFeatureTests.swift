import Domain
import Feature
import Foundation
import ThirdParty
import XCTest

@MainActor
final class ExploreFlowFeatureTests: XCTestCase {

    func test_검색버튼을_누르면_검색이_열린다() async {
        let store = TestStore(initialState: ExploreFlowFeature.State()) {
            ExploreFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.explore(.searchButtonTapped))
        await store.receive(\.explore.delegate.searchRequested) {
            $0.path = [.search]
        }
        XCTAssertNotNil(store.state.search)
    }

    func test_경로가_비면_검색_상태가_지워진다() async {
        let store = TestStore(
            initialState: ExploreFlowFeature.State(
                search: SearchFeature.State(),
                path: [.search]
            )
        ) {
            ExploreFlowFeature()
        }

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.search = nil
        }
    }

    func test_검색결과_카드탭은_상위로_올라간다() async {
        let store = TestStore(
            initialState: ExploreFlowFeature.State(
                search: SearchFeature.State(),
                path: [.search]
            )
        ) {
            ExploreFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.search(.delegate(.showContentDetail("c1"))))
        await store.receive(.delegate(.showContentDetail("c1")))
    }

    func test_탐색_세션만료는_위로_올린다() async {
        let store = TestStore(initialState: ExploreFlowFeature.State()) {
            ExploreFlowFeature()
        }

        await store.send(.explore(.delegate(.sessionExpired)))
        await store.receive(\.delegate.sessionExpired)

        XCTAssertEqual(store.state.path, [])
    }
}
