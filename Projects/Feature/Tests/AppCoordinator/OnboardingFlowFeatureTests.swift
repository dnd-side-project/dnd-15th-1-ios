import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class OnboardingFlowFeatureTests: XCTestCase {
    private let couple = Couple(
        partnerNickname: "픽둘",
        partnerIconID: 1
    )

    private var profile: UserProfile {
        UserProfile(
            nickname: "둘픽",
            iconID: 1,
            datePreference: nil
        )
    }

    private var coupleState: CoupleConnectFeature.State {
        CoupleConnectFeature.State(myNickname: "둘픽")
    }

    func test_닉네임_커플연결_데이트유형_저장까지_완료() async {
        let profile = self.profile
        let couple = self.couple
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                nickname: NicknameFeature.State(nickname: "둘픽"),
                path: [.nickname]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in profile }
            $0.profileClient.updateDatePreference = { _ in profile }
            $0.coupleClient.connect = { _ in couple }
        }

        await store.send(.nickname(.nextButtonTapped)) {
            $0.nickname.isSubmitting = true
        }
        await store.receive(\.nickname.updateNicknameResponse.success) {
            $0.nickname.isSubmitting = false
        }
        await store.receive(\.nickname.delegate.nicknameConfirmed) {
            $0.couple = CoupleConnectFeature.State(myNickname: "둘픽")
            $0.path = [.nickname, .couple]
        }

        await store.send(.couple(.codeChanged("AB12C"))) {
            $0.couple?.code = "AB12C"
        }
        await store.send(.couple(.connectButtonTapped)) {
            $0.couple?.isConnecting = true
        }
        await store.receive(\.couple.connectResponse.success) {
            $0.couple?.isConnecting = false
            $0.couple?.connectedCouple = couple
        }
        await store.receive(\.couple.delegate.showComplete) {
            $0.path = [.nickname, .couple, .coupleComplete]
        }

        await store.send(.couple(.completeButtonTapped))
        await store.receive(\.couple.delegate.connected) {
            $0.dateType = DateTypeFeature.State()
        }

        await selectAllAxes(store)

        await store.send(.dateType(.saveButtonTapped)) {
            $0.dateType?.isSubmitting = true
        }
        await store.receive(\.dateType.updateDatePreferenceResponse.success) {
            $0.dateType?.isSubmitting = false
        }
        await store.receive(\.dateType.delegate.saved)
        await store.receive(\.delegate.onboardingCompleted)

        // 덮개는 코디네이터가 main 으로 갈아탄 뒤 걷는다
        XCTAssertNotNil(store.state.dateType)
    }

    func test_커플건너뛰기도_데이트유형으로_간다() async {
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                couple: coupleState,
                path: [.nickname, .couple]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.profileClient.updateDatePreference = { _ in
                XCTFail("건너뛰기는 저장을 호출하지 않는다")
                return UserProfile(nickname: "둘픽", iconID: 1, datePreference: nil)
            }
        }

        await store.send(.couple(.skipButtonTapped)) {
            $0.couple?.isSkipConfirmPresented = true
        }
        await store.send(.couple(.skipConfirmed)) {
            $0.couple?.isSkipConfirmPresented = false
        }
        await store.receive(\.couple.delegate.skipped) {
            $0.dateType = DateTypeFeature.State()
        }

        await store.send(.dateType(.skipButtonTapped))
        await store.receive(\.dateType.delegate.skipped)
        await store.receive(\.delegate.onboardingCompleted)

        // 저장과 건너뛰기 모두 덮개를 남긴 채 완료만 올린다
        XCTAssertNotNil(store.state.dateType)
    }

    private func selectAllAxes(_ store: TestStoreOf<OnboardingFlowFeature>) async {
        await store.send(.dateType(.indoorOutdoorSelected(.indoor))) {
            $0.dateType?.indoorOutdoor = .indoor
        }
        await store.send(.dateType(.activityLevelSelected(.active))) {
            $0.dateType?.activityLevel = .active
        }
        await store.send(.dateType(.dateTimeSelected(.day))) {
            $0.dateType?.dateTime = .day
        }
        await store.send(.dateType(.dateFocusSelected(.food))) {
            $0.dateType?.dateFocus = .food
        }
    }
}

// 로그인 root 에서 온보딩으로 올라가는 지점만 따로 본다
@MainActor
final class OnboardingFlowSignInTests: XCTestCase {
    private let session = AuthSession(
        accessToken: "access",
        refreshToken: "refresh",
        userID: "1"
    )

    func test_로그인성공_온보딩미완료_닉네임을_올린다() async {
        let session = self.session
        let store = TestStore(initialState: OnboardingFlowFeature.State()) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.authClient.login = { _ in
                AuthBootstrap(session: session, isOnboardingCompleted: false)
            }
        }

        await store.send(.auth(.loginButtonTapped(.kakao))) {
            $0.auth.isLoading = true
            $0.auth.loadingProvider = .kakao
        }
        await store.receive(\.auth.loginResponse.success) {
            $0.auth.isLoading = false
            $0.auth.loadingProvider = nil
        }
        await store.receive(\.auth.delegate.loginSucceeded) {
            $0.path = [.nickname]
        }
        await store.receive(\.delegate.authenticated)
    }

    func test_로그인성공_온보딩완료_스택은_로그인그대로() async {
        let session = self.session
        let store = TestStore(initialState: OnboardingFlowFeature.State()) {
            OnboardingFlowFeature()
        }

        await store.send(
            .auth(.delegate(.loginSucceeded(userID: session.userID, isOnboardingCompleted: true)))
        )
        await store.receive(\.delegate.authenticated)

        XCTAssertTrue(store.state.path.isEmpty)
    }

    func test_다시_로그인하면_닉네임은_새_상태로_시작한다() async {
        let session = self.session
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                nickname: NicknameFeature.State(
                    nickname: "이전값",
                    isTermsSheetPresented: false
                )
            )
        ) {
            OnboardingFlowFeature()
        }

        await store.send(
            .auth(.delegate(.loginSucceeded(userID: session.userID, isOnboardingCompleted: false)))
        ) {
            $0.nickname = NicknameFeature.State()
            $0.path = [.nickname]
        }
        await store.receive(\.delegate.authenticated)
    }
}

// 온보딩을 빠져나갈 때의 로그아웃만 따로 본다
@MainActor
final class OnboardingFlowSignOutTests: XCTestCase {
    private var onboardingState: OnboardingFlowFeature.State {
        OnboardingFlowFeature.State(
            nickname: NicknameFeature.State(isTermsSheetPresented: false),
            path: [.nickname]
        )
    }

    func test_닉네임_뒤로가기_로그인으로_내려가고_로그아웃한다() async {
        let logoutExp = expectation(description: "logout called")
        let store = TestStore(initialState: onboardingState) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.authClient.logout = { logoutExp.fulfill() }
        }

        await store.send(.nickname(.backButtonTapped))
        await store.receive(\.nickname.delegate.back) {
            $0.path = []
        }
        await store.receive(\.signOutFinished)
        await store.receive(\.delegate.signedOut)
        await fulfillment(of: [logoutExp], timeout: 1)
    }

    func test_제출중에는_뒤로가기가_먹지_않는다() async {
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                nickname: NicknameFeature.State(nickname: "둘픽", isSubmitting: true),
                path: [.nickname]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.authClient.logout = {
                XCTFail("제출 중에는 로그아웃하지 않는다")
            }
        }

        await store.send(.nickname(.backButtonTapped))

        XCTAssertEqual(store.state.path, [.nickname])
    }

    func test_뷰가_로그인까지_되돌리면_로그아웃한다() async {
        let logoutExp = expectation(description: "logout called on swipe back")
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                nickname: NicknameFeature.State(isTermsSheetPresented: false),
                couple: CoupleConnectFeature.State(myNickname: "둘픽"),
                path: [.nickname]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.authClient.logout = { logoutExp.fulfill() }
        }

        await store.send(.pathChanged([])) {
            $0.path = []
            $0.couple = nil
        }
        await store.receive(\.signOutFinished)
        await store.receive(\.delegate.signedOut)
        await fulfillment(of: [logoutExp], timeout: 1)
    }

    func test_커플에서_닉네임으로_물러나도_로그아웃하지_않는다() async {
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                couple: CoupleConnectFeature.State(myNickname: "둘픽"),
                path: [.nickname, .couple]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.authClient.logout = {
                XCTFail("커플에서 닉네임으로 물러나는 것은 로그아웃이 아니다")
            }
        }

        await store.send(.pathChanged([.nickname])) {
            $0.path = [.nickname]
        }
    }

    func test_로그아웃이_실패해도_로그인으로_돌아가고_알린다() async {
        let store = TestStore(initialState: onboardingState) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.authClient.logout = { throw AuthError.storage }
        }

        await store.send(.pathChanged([])) {
            $0.path = []
        }
        await store.receive(\.signOutFinished) {
            $0.auth.toast = .error("로그아웃에 실패했습니다.")
        }
        await store.receive(\.delegate.signedOut)
    }
}

// 커플 구간의 경로 조작만 따로 본다
@MainActor
final class OnboardingFlowPathTests: XCTestCase {
    private let couple = Couple(
        partnerNickname: "픽둘",
        partnerIconID: 1
    )

    func test_코드입력_연결완료_쌓이고_뒤로가기로_빠진다() async {
        let couple = self.couple
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                couple: CoupleConnectFeature.State(
                    myNickname: "둘픽",
                    code: "AB12C"
                ),
                path: [.nickname, .couple]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.coupleClient.connect = { _ in couple }
        }

        await store.send(.couple(.codeInputButtonTapped))
        await store.receive(\.couple.delegate.showCodeInput) {
            $0.path = [.nickname, .couple, .coupleCodeInput]
        }

        await store.send(.couple(.connectButtonTapped)) {
            $0.couple?.isConnecting = true
        }
        await store.receive(\.couple.connectResponse.success) {
            $0.couple?.isConnecting = false
            $0.couple?.connectedCouple = couple
        }
        await store.receive(\.couple.delegate.showComplete) {
            $0.path = [.nickname, .couple, .coupleCodeInput, .coupleComplete]
        }

        await store.send(.couple(.backButtonTapped))
        await store.receive(\.couple.delegate.back) {
            $0.path = [.nickname, .couple, .coupleCodeInput]
        }

        await store.send(.couple(.backButtonTapped))
        await store.receive(\.couple.delegate.back) {
            $0.path = [.nickname, .couple]
        }
    }

    func test_경로가_비어있으면_뒤로가기는_아무것도_안한다() async {
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                couple: CoupleConnectFeature.State(myNickname: "둘픽")
            )
        ) {
            OnboardingFlowFeature()
        }

        await store.send(.couple(.backButtonTapped))
        await store.receive(\.couple.delegate.back)

        XCTAssertTrue(store.state.path.isEmpty)
    }

    func test_뷰가_경로를_줄이면_그대로_반영된다() async {
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                couple: CoupleConnectFeature.State(myNickname: "둘픽"),
                path: [.nickname, .couple, .coupleCodeInput]
            )
        ) {
            OnboardingFlowFeature()
        }

        await store.send(.pathChanged([.nickname, .couple])) {
            $0.path = [.nickname, .couple]
        }
    }

    func test_이어하기_상태는_닉네임부터_시작한다() {
        XCTAssertEqual(OnboardingFlowFeature.State.resumingOnboarding.path, [.nickname])
    }
}

// 자식 셋의 세션 만료가 그대로 위로 올라가는지만 본다
@MainActor
final class OnboardingFlowSessionExpiredTests: XCTestCase {
    private var allSelectedDateType: DateTypeFeature.State {
        DateTypeFeature.State(
            indoorOutdoor: .indoor,
            activityLevel: .active,
            dateTime: .day,
            dateFocus: .food
        )
    }

    func test_닉네임_세션만료_승격() async {
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                nickname: NicknameFeature.State(nickname: "둘픽"),
                path: [.nickname]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in throw ProfileError.unauthorized }
        }

        await store.send(.nickname(.nextButtonTapped)) {
            $0.nickname.isSubmitting = true
        }
        await store.receive(\.nickname.updateNicknameResponse.failure) {
            $0.nickname.isSubmitting = false
        }
        await store.receive(\.nickname.delegate.sessionExpired)
        await store.receive(\.delegate.sessionExpired)

        XCTAssertNil(store.state.couple)
        XCTAssertEqual(store.state.path, [.nickname])
    }

    func test_커플_세션만료_승격() async {
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                couple: CoupleConnectFeature.State(myNickname: "둘픽"),
                path: [.nickname, .couple]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.coupleClient.inviteCode = { throw CoupleError.unauthorized }
        }

        await store.send(.couple(.onAppear)) {
            $0.couple?.isLoadingInviteCode = true
            $0.couple?.hasAttemptedInviteCode = true
        }
        await store.receive(\.couple.inviteCodeResponse.failure) {
            $0.couple?.isLoadingInviteCode = false
        }
        await store.receive(\.couple.delegate.sessionExpired)
        await store.receive(\.delegate.sessionExpired)

        XCTAssertNil(store.state.dateType)
    }

    func test_데이트유형_세션만료_승격() async {
        let store = TestStore(
            initialState: OnboardingFlowFeature.State(
                couple: CoupleConnectFeature.State(myNickname: "둘픽"),
                dateType: allSelectedDateType,
                path: [.nickname, .couple]
            )
        ) {
            OnboardingFlowFeature()
        } withDependencies: {
            $0.profileClient.updateDatePreference = { _ in throw ProfileError.unauthorized }
        }

        await store.send(.dateType(.saveButtonTapped)) {
            $0.dateType?.isSubmitting = true
        }
        await store.receive(\.dateType.updateDatePreferenceResponse.failure) {
            $0.dateType?.isSubmitting = false
        }
        await store.receive(\.dateType.delegate.sessionExpired)
        await store.receive(\.delegate.sessionExpired)

        // 만료는 위로만 올라가고 덮개는 코디네이터가 걷는다
        XCTAssertNotNil(store.state.dateType)
    }
}
