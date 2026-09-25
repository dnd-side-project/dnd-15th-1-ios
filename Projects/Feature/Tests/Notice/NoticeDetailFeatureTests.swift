import Domain
import Feature
import Foundation
import ThirdParty
import XCTest

@MainActor
final class NoticeDetailFeatureTests: XCTestCase {

    private let sample = Notice(
        id: "1",
        title: "둘픽 업데이트 안내",
        content: "새 기능이 추가되었어요",
        createdAt: Date(timeIntervalSince1970: 1_785_943_800)
    )

    func test_받은_공지를_그대로_들고_있다() {
        let state = NoticeDetailFeature.State(notice: sample)
        XCTAssertEqual(state.notice, sample)
    }

    func test_뒤로가기는_위로_올린다() async {
        let store = TestStore(
            initialState: NoticeDetailFeature.State(notice: sample)
        ) {
            NoticeDetailFeature()
        }

        await store.send(.backButtonTapped)
        await store.receive(\.delegate.back)
    }
}
