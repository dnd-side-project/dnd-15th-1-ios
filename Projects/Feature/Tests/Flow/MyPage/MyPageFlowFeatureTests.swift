import Domain
import Feature
import Foundation
import ThirdParty
import XCTest

@MainActor
final class MyPageFlowFeatureTests: XCTestCase {

    func test_데이트유형을_누르면_나의_데이트유형이_열린다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나")
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.myPage(.delegate(.dateTypeRequested(nil)))) {
            $0.path = [.dateType]
        }
        XCTAssertNotNil(store.state.dateType)
    }

    func test_연결되어_있으면_연결관리가_열린다() async {
        let me = CoupleMember(nickname: "나", iconID: 1)
        let partner = CoupleMember(nickname: "짝", iconID: 2)
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나")
            )
        ) {
            MyPageFlowFeature()
        } withDependencies: {
            $0.coupleClient.current = { .connected(me: me, partner: partner, daysTogether: 30) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.myPage(.connectionTapped))
        await store.receive(\.myPage.connectionStatusResolved)
        await store.receive(\.myPage.delegate.connectionManageRequested) {
            $0.path = [.connection]
        }
        XCTAssertEqual(store.state.connection?.me, me)
        XCTAssertEqual(store.state.connection?.partner, partner)
        XCTAssertEqual(store.state.connection?.daysTogether, 30)
    }

    func test_미연결이면_커플연결이_열린다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나")
            )
        ) {
            MyPageFlowFeature()
        } withDependencies: {
            $0.coupleClient.current = { .notConnected }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.myPage(.connectionTapped))
        await store.receive(\.myPage.connectionStatusResolved)
        await store.receive(\.myPage.delegate.coupleConnectRequested) {
            $0.path = [.connect]
        }
        XCTAssertEqual(store.state.couple?.myNickname, "나")
    }

    func test_커플_세단계가_차례로_쌓인다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.connect],
                couple: CoupleConnectFeature.State(myNickname: "나", showsSkip: false)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.couple(.delegate(.showCodeInput))) {
            $0.path = [.connect, .codeInput]
        }
        await store.send(.couple(.delegate(.showComplete))) {
            $0.path = [.connect, .codeInput, .complete]
        }
    }

    func test_연결이_끝나면_커플이_닫히고_연결관리로_바뀐다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.connect, .codeInput],
                couple: CoupleConnectFeature.State(myNickname: "나", showsSkip: false)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.couple(.delegate(.connected(partner: CoupleMember(nickname: "짝", iconID: 2))))) {
            $0.couple = nil
            $0.path = [.connection]
        }
        XCTAssertNotNil(store.state.connection)
    }

    func test_뒤로_가면_자식_상태가_지워진다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.dateType],
                dateType: DateTypeFeature.State(showsSkip: false)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.dateType = nil
        }
    }

    func test_연결관리에서_해제하면_마이페이지로_돌아간다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.connection],
                connection: ConnectionManageFeature.State()
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.connection(.delegate(.disconnected))) {
            $0.path = []
            $0.connection = nil
        }
    }

    func test_데이트유형을_저장하면_경로가_빠지고_새_값이_아래로_간다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.dateType],
                dateType: DateTypeFeature.State(showsSkip: false)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        let preference = DatePreference(
            indoorOutdoor: .outdoor,
            activityLevel: .active,
            dateTime: .night,
            dateFocus: .food
        )
        let profile = UserProfile(nickname: "나", iconID: 1, datePreference: preference)
        await store.send(.dateType(.delegate(.saved(profile)))) {
            $0.path = []
            $0.dateType = nil
        }
        await store.receive(\.myPage.datePreferenceUpdated) {
            $0.myPage.datePreference = preference
        }
    }

    func test_마이페이지_세션만료는_위로_올린다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나")
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.myPage(.delegate(.sessionExpired)))
        await store.receive(\.delegate.sessionExpired)
    }

    func test_데이트유형_세션만료는_상태를_지우고_위로_올린다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.dateType],
                dateType: DateTypeFeature.State(showsSkip: false)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.dateType(.delegate(.sessionExpired))) {
            $0.path = []
            $0.dateType = nil
        }
        await store.receive(\.delegate.sessionExpired)
    }

    func test_연결관리_세션만료는_상태를_지우고_위로_올린다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.connection],
                connection: ConnectionManageFeature.State()
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.connection(.delegate(.sessionExpired))) {
            $0.path = []
            $0.connection = nil
        }
        await store.receive(\.delegate.sessionExpired)
    }

    func test_커플_세션만료는_상태를_지우고_위로_올린다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.connect, .codeInput],
                couple: CoupleConnectFeature.State(myNickname: "나", showsSkip: false)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.couple(.delegate(.sessionExpired))) {
            $0.path = []
            $0.couple = nil
        }
        await store.receive(\.delegate.sessionExpired)
    }

    func test_탈퇴모달_닫기는_마이페이지로_그대로_넘어간다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나", isWithdrawModalPresented: true)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        XCTAssertTrue(store.state.isWithdrawModalPresented)

        await store.send(.dismissWithdrawModal)
        await store.receive(\.myPage.dismissWithdrawModal)

        XCTAssertFalse(store.state.isWithdrawModalPresented)
    }
}

@MainActor
final class MyPageFlowNoticeTests: XCTestCase {
    private var sampleNotice: Notice {
        Notice(
            id: "1",
            title: "둘픽 업데이트 안내",
            content: "새 기능이 추가되었어요",
            createdAt: Date(timeIntervalSince1970: 1_785_943_800)
        )
    }

    func test_공지사항을_누르면_공지_목록이_열린다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나")
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.myPage(.delegate(.noticeRequested))) {
            $0.path = [.noticeList]
        }
        XCTAssertNotNil(store.state.noticeList)
    }

    func test_공지_한_건을_누르면_상세가_열린다() async {
        let picked = sampleNotice
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.noticeList],
                noticeList: NoticeListFeature.State(notices: [picked], hasLoaded: true)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.noticeList(.delegate(.noticeSelected(picked)))) {
            $0.path = [.noticeList, .noticeDetail]
        }
        XCTAssertEqual(store.state.noticeDetail?.notice, picked)
    }

    func test_상세에서_뒤로_가면_목록만_남는다() async {
        let picked = sampleNotice
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.noticeList, .noticeDetail],
                noticeList: NoticeListFeature.State(notices: [picked], hasLoaded: true),
                noticeDetail: NoticeDetailFeature.State(notice: picked)
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.noticeDetail(.delegate(.back))) {
            $0.path = [.noticeList]
        }
        XCTAssertNil(store.state.noticeDetail)
        XCTAssertNotNil(store.state.noticeList)
    }

    func test_목록에서_뒤로_가면_마이페이지로_돌아간다() async {
        let store = TestStore(
            initialState: MyPageFlowFeature.State(
                myPage: MyPageFeature.State(nickname: "나"),
                path: [.noticeList],
                noticeList: NoticeListFeature.State()
            )
        ) {
            MyPageFlowFeature()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.noticeList(.delegate(.back))) {
            $0.path = []
        }
        XCTAssertNil(store.state.noticeList)
    }
}
