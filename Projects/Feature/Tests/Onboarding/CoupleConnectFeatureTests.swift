import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class CoupleConnectFeatureTests: XCTestCase {
    private let inviteCode = InviteCode(value: "AB12C", shareURL: nil)

    func test_진입_내코드_로딩후_표시() async {
        let inviteCode = self.inviteCode
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.inviteCode = { inviteCode }
            $0.coupleClient.current = { nil }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
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
            $0.coupleClient.current = { nil }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
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
            $0.coupleClient.current = { nil }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
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
            $0.coupleClient.current = { nil }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
        }
        await store.receive(\.inviteCodeResponse.failure) {
            $0.isLoadingInviteCode = false
        }
        await store.receive(\.delegate.sessionExpired)

        XCTAssertNil(store.state.toast)
        XCTAssertNil(store.state.inviteCodeError)
    }
}

// 스킵·코드 입력·연결 성공은 케이스가 많아 별도 클래스로 둔다. type_body_length 한계 때문이다
@MainActor
final class CoupleConnectInteractionTests: XCTestCase {
    private let couple = Couple(
        partnerNickname: "픽둘",
        partnerIconID: 1
    )

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
        // 화면 이동 요청이 안 나갔다는 건 TestStore 가 미수신 델리게이트를 잡아 확인한다
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

        // 입력칸이 다시 열리며 텍스트필드가 같은 값을 돌려보내도 메시지는 남는다
        await store.send(.codeChanged("AB12C"))
        XCTAssertEqual(store.state.toast, .error("유효하지 않은 코드에요. 다시 확인해주세요"))

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
        // 실패했으니 완료 화면 요청도 나가지 않는다

        await store.send(.dismissToast) {
            $0.toast = nil
        }
    }

    func test_화면이동시_토스트_정리() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                code: "AB12C",
                toast: .error("요청이 많아요. 잠시 후 다시 시도해 주세요.")
            )
        ) {
            CoupleConnectFeature()
        }

        XCTAssertFalse(store.state.isConnectEnabled)

        await store.send(.backButtonTapped) {
            $0.toast = nil
        }
        await store.receive(\.delegate.back)
        XCTAssertTrue(store.state.isConnectEnabled)
    }

    func test_연결성공_완료화면_델리게이트() async {
        let couple = self.couple
        let requestedCode = LockIsolated<String?>(nil)
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
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
        }
        await store.receive(\.delegate.showComplete)

        XCTAssertEqual(requestedCode.value, "AB12C")
    }

    func test_완료화면_확인_연결델리게이트() async {
        let couple = self.couple
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
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
    func test_코드입력버튼_코드입력화면_델리게이트() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        }

        await store.send(.codeInputButtonTapped)
        await store.receive(\.delegate.showCodeInput)
    }

    func test_뒤로가기_델리게이트_전달() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                code: "AB12C",
                toast: .error("요청이 많아요. 잠시 후 다시 시도해 주세요.")
            )
        ) {
            CoupleConnectFeature()
        }

        await store.send(.backButtonTapped) {
            $0.toast = nil
        }
        await store.receive(\.delegate.back)
    }

    func test_토스트없는_뒤로가기_상태변화없음() async {
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽")) {
            CoupleConnectFeature()
        }

        await store.send(.backButtonTapped)
        await store.receive(\.delegate.back)
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
            $0.coupleClient.current = { nil }
        }

        await store.send(.onAppear) {
            $0.isLoadingInviteCode = true
            $0.hasAttemptedInviteCode = true
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
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

// 연결 상태 조회는 케이스가 많아 별도 클래스로 둔다. type_body_length 한계 때문이다
@MainActor
final class CoupleConnectStatusCheckTests: XCTestCase {
    private let inviteCode = InviteCode(value: "AB12C", shareURL: nil)

    private func connectedStatus() -> CoupleStatus {
        CoupleStatus(
            connected: true,
            me: CoupleMember(nickname: "둘픽", iconID: 1),
            partner: CoupleMember(nickname: "픽둘", iconID: 2),
            daysTogether: 0
        )
    }

    func test_진입시_이미연결이면_완료화면으로() async {
        let inviteCode = self.inviteCode
        let status = connectedStatus()
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽", inviteCode: inviteCode)) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.current = { status }
        }

        await store.send(.onAppear) {
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
            $0.connectedCouple = Couple(partnerNickname: "픽둘", partnerIconID: 2)
        }
        await store.receive(\.delegate.showComplete)
    }

    func test_진입시_미연결이면_그대로머문다() async {
        let inviteCode = self.inviteCode
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽", inviteCode: inviteCode)) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.current = { nil }
        }

        await store.send(.onAppear) {
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
        }
        XCTAssertNil(store.state.connectedCouple)
    }

    func test_상대정보가없으면_안넘어간다() async {
        let inviteCode = self.inviteCode
        let status = CoupleStatus(
            connected: true,
            me: CoupleMember(nickname: "둘픽", iconID: 1),
            partner: nil,
            daysTogether: nil
        )
        let store = TestStore(initialState: CoupleConnectFeature.State(myNickname: "둘픽", inviteCode: inviteCode)) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.current = { status }
        }

        await store.send(.onAppear) {
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
        }
        XCTAssertNil(store.state.connectedCouple)
    }

    func test_앱이앞으로오면_다시묻는다() async {
        let status = connectedStatus()
        let store = TestStore(
            initialState: CoupleConnectFeature.State(myNickname: "둘픽", inviteCode: inviteCode)
        ) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.current = { status }
        }

        await store.send(.sceneBecameActive) {
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.success) {
            $0.isCheckingConnection = false
            $0.connectedCouple = Couple(partnerNickname: "픽둘", partnerIconID: 2)
        }
        await store.receive(\.delegate.showComplete)
    }

    func test_이미완료화면이면_안묻는다() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(
                myNickname: "둘픽",
                inviteCode: inviteCode,
                connectedCouple: Couple(partnerNickname: "픽둘", partnerIconID: 2)
            )
        ) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.current = {
                XCTFail("이미 연결된 뒤에는 조회하지 않아야 한다")
                return nil
            }
        }

        await store.send(.sceneBecameActive)
    }

    func test_네트워크실패는_조용하다() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(myNickname: "둘픽", inviteCode: inviteCode)
        ) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.current = { throw CoupleError.network }
        }

        await store.send(.sceneBecameActive) {
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.failure) {
            $0.isCheckingConnection = false
        }
        XCTAssertNil(store.state.toast)
        XCTAssertNil(store.state.connectedCouple)
    }

    func test_세션만료는_위로올린다() async {
        let store = TestStore(
            initialState: CoupleConnectFeature.State(myNickname: "둘픽", inviteCode: inviteCode)
        ) {
            CoupleConnectFeature()
        } withDependencies: {
            $0.coupleClient.current = { throw CoupleError.unauthorized }
        }

        await store.send(.sceneBecameActive) {
            $0.isCheckingConnection = true
        }
        await store.receive(\.connectionStatusResponse.failure) {
            $0.isCheckingConnection = false
        }
        await store.receive(\.delegate.sessionExpired)
    }
}
