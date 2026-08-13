import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class CoupleConnectFeatureTests: XCTestCase {
    private let inviteCode = InviteCode(value: "AB12C", shareURL: nil)
    private let couple = Couple(
        partnerNickname: "픽둘",
        partnerIconID: 1
    )

    func test_진입_내코드_로딩후_표시() async {
        let inviteCode = self.inviteCode
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.inviteCode = { inviteCode }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
        }
        await store.receive(\.inviteCodeResponse.success) {
            $0.isLoadingInviteCode = false
            $0.inviteCode = inviteCode
        }
    }

    func test_내코드실패_재시도_가능() async {
        let inviteCode = self.inviteCode
        let shouldFail = LockIsolated(true)
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.inviteCode = {
                if shouldFail.value {
                    throw CoupleError.network
                }
                return inviteCode
            }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
        }
        await store.receive(\.inviteCodeResponse.failure) {
            $0.isLoadingInviteCode = false
            $0.inviteCodeError = "네트워크 연결을 확인해 주세요"
        }
        XCTAssertNil(store.state.toast)

        shouldFail.setValue(false)

        await store.send(.retryInviteCodeButtonTapped) {
            $0.isLoadingInviteCode = true
            $0.inviteCodeError = nil
        }
        await store.receive(\.inviteCodeResponse.success) {
            $0.isLoadingInviteCode = false
            $0.inviteCode = inviteCode
        }
    }

    func test_내코드_알수없는실패_다른문구_노출() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.inviteCode = { throw CoupleError.unknown }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
        }
        await store.receive(\.inviteCodeResponse.failure) {
            $0.isLoadingInviteCode = false
            $0.inviteCodeError = "잠시 후 다시 시도해 주세요"
        }
        XCTAssertNil(store.state.toast)
    }

    func test_내코드_인증실패_세션만료_델리게이트() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.inviteCode = { throw CoupleError.unauthorized }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
        }
        await store.receive(\.inviteCodeResponse.failure) {
            $0.isLoadingInviteCode = false
        }
        await store.receive(\.delegate.sessionExpired)

        XCTAssertNil(store.state.toast)
        XCTAssertNil(store.state.inviteCodeError)
    }

    func test_스킵확인_네_스킵델리게이트() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        }

        await store.send(.skipButtonTapped) {
            $0.isSkipConfirmPresented = true
        }
        await store.send(.skipConfirmed) {
            $0.isSkipConfirmPresented = false
        }
        await store.receive(\.delegate.skipped)
    }

    func test_스킵확인_연결할게요_모달만_닫힘() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        }

        await store.send(.skipButtonTapped) {
            $0.isSkipConfirmPresented = true
        }
        await store.send(.skipConfirmDismissed) {
            $0.isSkipConfirmPresented = false
        }
        XCTAssertTrue(store.state.path.isEmpty)
    }

    func test_소문자입력_대문자로_변환() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        }

        await store.send(.codeChanged("ab-1c 2d3")) {
            $0.code = "AB1C2"
        }
    }

    func test_다섯자미만_연결버튼_비활성() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        }

        await store.send(.codeChanged("AB12")) {
            $0.code = "AB12"
        }
        XCTAssertFalse(store.state.isConnectEnabled)

        await store.send(.connectButtonTapped)

        await store.send(.codeChanged("AB12C")) {
            $0.code = "AB12C"
        }
        XCTAssertTrue(store.state.isConnectEnabled)
    }

    func test_유효하지않은코드_토스트_노출() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                path: [.codeInput],
                code: "AB12C"
            )
        ) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.connect = { _ in throw CoupleError.invalidInviteCode }
        }

        await store.send(.connectButtonTapped) {
            $0.isConnecting = true
        }
        await store.receive(\.connectResponse.failure) {
            $0.isConnecting = false
            $0.toast = .error("유효하지 않은 코드에요. 다시 확인해주세요")
        }
        XCTAssertEqual(store.state.code, "AB12C")
        XCTAssertFalse(store.state.isConnectEnabled)

        await store.send(.codeChanged("AB12D")) {
            $0.code = "AB12D"
            $0.toast = nil
        }
        XCTAssertTrue(store.state.isConnectEnabled)
    }

    func test_레이트리밋_토스트_노출() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                path: [.codeInput],
                code: "AB12C"
            )
        ) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.connect = { _ in throw CoupleError.rateLimited }
        }

        await store.send(.connectButtonTapped) {
            $0.isConnecting = true
        }
        await store.receive(\.connectResponse.failure) {
            $0.isConnecting = false
            $0.toast = .error("요청이 많아요. 잠시 후 다시 시도해 주세요.")
        }
        XCTAssertEqual(store.state.path, [.codeInput])

        await store.send(.dismissToast) {
            $0.toast = nil
        }
    }

    func test_화면이동시_토스트_정리() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                path: [.codeInput],
                code: "AB12C",
                toast: .error("요청이 많아요. 잠시 후 다시 시도해 주세요.")
            )
        ) {
            CoupleConnectFeature()
        }

        XCTAssertFalse(store.state.isConnectEnabled)

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.toast = nil
        }
        XCTAssertTrue(store.state.isConnectEnabled)
    }

    func test_연결성공_완료화면_push() async {
        let couple = self.couple
        let requestedCode = LockIsolated<String?>(nil)
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                path: [.codeInput],
                code: "AB12C"
            )
        ) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.connect = { code in
                requestedCode.setValue(code)
                return couple
            }
        }

        await store.send(.connectButtonTapped) {
            $0.isConnecting = true
        }
        await store.receive(\.connectResponse.success) {
            $0.isConnecting = false
            $0.connectedCouple = couple
            $0.path = [.codeInput, .complete]
        }

        XCTAssertEqual(requestedCode.value, "AB12C")
    }

    func test_완료화면_확인_연결델리게이트() async {
        let couple = self.couple
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                path: [.codeInput, .complete],
                code: "AB12C",
                connectedCouple: couple
            )
        ) {
            CoupleConnectFeature()
        }

        await store.send(.completeButtonTapped)
        await store.receive(.delegate(.connected(couple)))
    }
}

// 위 클래스가 type_body_length 한계라 네비게이션 케이스는 따로 둔다
@MainActor
final class CoupleConnectNavigationTests: XCTestCase {
    func test_뒤로가기_마지막화면_제거() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                path: [.codeInput],
                code: "AB12C",
                toast: .error("요청이 많아요. 잠시 후 다시 시도해 주세요.")
            )
        ) {
            CoupleConnectFeature()
        }

        await store.send(.backButtonTapped) {
            $0.path = []
            $0.toast = nil
        }
    }

    func test_경로없음_뒤로가기_변화없음() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        }

        await store.send(.backButtonTapped)
        XCTAssertTrue(store.state.path.isEmpty)
    }
}

// 코드 자리에 시머를 띄울지 실패를 띄울지 가르는 상태 조합만 따로 본다
@MainActor
final class CoupleConnectInviteCodePlaceholderTests: XCTestCase {
    func test_세션만료로_코드도_에러도_없으면_시도완료_상태로_남는다() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.inviteCode = { throw CoupleError.unauthorized }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
        }
        await store.receive(\.inviteCodeResponse.failure) {
            $0.isLoadingInviteCode = false
        }
        await store.receive(\.delegate.sessionExpired)

        // 이 조합이면 뷰는 시머가 아니라 "코드를 불러오지 못했어요" 를 그린다
        XCTAssertTrue(store.state.hasAttemptedInviteCode)
        XCTAssertFalse(store.state.isLoadingInviteCode)
        XCTAssertNil(store.state.inviteCode)
        XCTAssertNil(store.state.inviteCodeError)
    }
}
