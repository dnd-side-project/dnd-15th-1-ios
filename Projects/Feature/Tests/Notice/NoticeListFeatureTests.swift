import Domain
import Feature
import Foundation
import ThirdParty
import XCTest

// 의존성 클로저가 @Sendable 이라 MainActor 안에 두면 못 부른다
private func notice(_ id: String) -> Notice {
    Notice(
        id: id,
        title: "공지 \(id)",
        content: "본문 \(id)",
        createdAt: Date(timeIntervalSince1970: 1_785_943_800)
    )
}

@MainActor
final class NoticeListFeatureTests: XCTestCase {
    func test_처음_나타나면_첫_페이지를_받는다() async {
        let asked = LockIsolated<[Int]>([])
        let store = TestStore(initialState: NoticeListFeature.State()) {
            NoticeListFeature()
        } withDependencies: {
            $0.noticeClient.notices = { page in
                asked.withValue { $0.append(page) }
                return NoticePage(items: [notice("1")], hasNext: true)
            }
        }

        await store.send(.onAppear)
        await store.receive(\.noticesLoaded) {
            $0.hasLoaded = true
            $0.notices = [notice("1")]
            $0.hasNext = true
            $0.page = 1
        }

        XCTAssertEqual(asked.value, [0])
    }

    func test_이미_받았으면_다시_나타나도_안_부른다() async {
        let asked = LockIsolated<[Int]>([])
        let store = TestStore(
            initialState: NoticeListFeature.State(
                notices: [notice("1")],
                page: 1,
                hasNext: true,
                hasLoaded: true
            )
        ) {
            NoticeListFeature()
        } withDependencies: {
            $0.noticeClient.notices = { page in
                asked.withValue { $0.append(page) }
                return NoticePage(items: [notice("9")], hasNext: false)
            }
        }

        await store.send(.onAppear)

        XCTAssertEqual(asked.value, [])
        XCTAssertEqual(store.state.notices, [notice("1")])
        XCTAssertEqual(store.state.page, 1)
    }

    func test_못_불러오면_빈_목록이_된다() async {
        struct Failure: Error {}
        let store = TestStore(initialState: NoticeListFeature.State()) {
            NoticeListFeature()
        } withDependencies: {
            $0.noticeClient.notices = { _ in throw Failure() }
        }

        await store.send(.onAppear)
        await store.receive(\.noticesLoaded) {
            $0.hasLoaded = true
            $0.notices = []
            $0.hasNext = false
            $0.page = 1
        }
    }

    func test_끝에_닿으면_다음_페이지를_뒤에_붙인다() async {
        let asked = LockIsolated<[Int]>([])
        let store = TestStore(
            initialState: NoticeListFeature.State(
                notices: [notice("1")],
                page: 1,
                hasNext: true,
                hasLoaded: true
            )
        ) {
            NoticeListFeature()
        } withDependencies: {
            $0.noticeClient.notices = { page in
                asked.withValue { $0.append(page) }
                return NoticePage(items: [notice("2")], hasNext: false)
            }
        }

        await store.send(.reachedEnd) {
            $0.isLoadingMore = true
        }
        await store.receive(\.moreNoticesLoaded) {
            $0.isLoadingMore = false
            $0.notices = [notice("1"), notice("2")]
            $0.hasNext = false
            $0.page = 2
        }

        XCTAssertEqual(asked.value, [1])
    }

    func test_다음_페이지가_없으면_더_안_부른다() async {
        let store = TestStore(
            initialState: NoticeListFeature.State(
                notices: [notice("1")],
                page: 1,
                hasNext: false,
                hasLoaded: true
            )
        ) {
            NoticeListFeature()
        }

        await store.send(.reachedEnd)
    }

    func test_이미_부르는_중이면_더_안_부른다() async {
        let store = TestStore(
            initialState: NoticeListFeature.State(
                notices: [notice("1")],
                page: 1,
                hasNext: true,
                hasLoaded: true,
                isLoadingMore: true
            )
        ) {
            NoticeListFeature()
        }

        await store.send(.reachedEnd)
    }

    func test_다음_페이지를_못_받으면_목록을_그대로_둔다() async {
        struct Failure: Error {}
        let asked = LockIsolated<[Int]>([])
        let store = TestStore(
            initialState: NoticeListFeature.State(
                notices: [notice("1")],
                page: 1,
                hasNext: true,
                hasLoaded: true
            )
        ) {
            NoticeListFeature()
        } withDependencies: {
            $0.noticeClient.notices = { page in
                asked.withValue { $0.append(page) }
                throw Failure()
            }
        }

        await store.send(.reachedEnd) {
            $0.isLoadingMore = true
        }
        await store.receive(\.moreNoticesLoaded) {
            $0.isLoadingMore = false
        }
        XCTAssertEqual(store.state.notices, [notice("1")])
        XCTAssertEqual(store.state.page, 1)
        XCTAssertEqual(asked.value, [1])
    }

    func test_줄을_누르면_공지를_통째로_올린다() async {
        let picked = notice("1")
        let store = TestStore(
            initialState: NoticeListFeature.State(notices: [picked], hasLoaded: true)
        ) {
            NoticeListFeature()
        }

        await store.send(.noticeTapped(picked))
        await store.receive(\.delegate.noticeSelected)
    }

    func test_뒤로가기는_위로_올린다() async {
        let store = TestStore(initialState: NoticeListFeature.State()) {
            NoticeListFeature()
        }

        await store.send(.backButtonTapped)
        await store.receive(\.delegate.back)
    }
}
