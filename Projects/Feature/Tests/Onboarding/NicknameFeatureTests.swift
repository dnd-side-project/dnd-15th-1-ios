import Domain
import Feature
import ThirdParty
import XCTest

@MainActor
final class NicknameFeatureTests: XCTestCase {
    private let profile = UserProfile(
        nickname: "둘픽",
        iconID: 1,
        datePreference: nil
    )

    func test_공백만입력_입력칸_비어있음() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(\.binding.nickname, "   ")

        XCTAssertEqual(store.state.nickname, "")
        XCTAssertFalse(store.state.isNextEnabled)
        XCTAssertNil(store.state.lengthError)
    }

    func test_공백섞인입력_공백_제거() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(\.binding.nickname, " 둘 픽\n") {
            $0.nickname = "둘픽"
        }
        XCTAssertTrue(store.state.isNextEnabled)
    }

    func test_여덟자입력_일곱자까지만_입력() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(\.binding.nickname, "여덟글자짜리닉넴") {
            $0.nickname = "여덟글자짜리닉"
        }
        XCTAssertEqual(store.state.lengthError, "최대 6글자 내로 입력해주세요")
        XCTAssertFalse(store.state.isNextEnabled)
    }

    func test_일곱자에서_한글자더입력_무시() async {
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "일곱글자닉네임",
                isTermsSheetPresented: false
            )
        ) {
            NicknameFeature()
        }

        await store.send(\.binding.nickname, "일곱글자닉네임둘")

        XCTAssertEqual(store.state.nickname, "일곱글자닉네임")
    }

    /// 한글은 조합 중간값이 그대로 올라온다. 잘리는 지점까지 앞 글자가 깨지지 않아야 한다
    func test_한글조합_중간값_그대로올라와도_일곱자에서_멈춤() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        // "가나다라마바사" 를 두벌식으로 칠 때 텍스트필드가 올려보내는 값 그대로
        let composing = [
            "ㄱ", "가", "간", "가나", "가낟", "가나다", "가나달", "가나다라",
            "가나다람", "가나다라마", "가나다라맙", "가나다라마바", "가나다라마밧", "가나다라마바사"
        ]
        for value in composing {
            await store.send(\.binding.nickname, value) {
                $0.nickname = value
            }
        }

        // 여덟 번째 글자의 첫 자음은 앞 글자의 받침으로 붙어 아직 일곱 자다
        await store.send(\.binding.nickname, "가나다라마바상") {
            $0.nickname = "가나다라마바상"
        }
        // 모음이 붙어 여덟 자가 되는 순간부터는 앞 일곱 자만 남는다
        await store.send(\.binding.nickname, "가나다라마바사아") {
            $0.nickname = "가나다라마바사"
        }
        XCTAssertFalse(store.state.isNextEnabled)
    }

    func test_긴문자열_붙여넣기_일곱자로_잘림() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(\.binding.nickname, "가나다라마바사아자차카타파하") {
            $0.nickname = "가나다라마바사"
        }
        XCTAssertEqual(store.state.lengthError, "최대 6글자 내로 입력해주세요")
        XCTAssertFalse(store.state.isNextEnabled)
    }

    func test_일곱자입력_에러문구_노출() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(\.binding.nickname, "일곱글자닉네임") {
            $0.nickname = "일곱글자닉네임"
        }
        XCTAssertEqual(store.state.lengthError, "최대 6글자 내로 입력해주세요")
        XCTAssertFalse(store.state.isNextEnabled)
    }

    func test_여섯자입력_다음버튼_활성() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(\.binding.nickname, "여섯글자닉넴") {
            $0.nickname = "여섯글자닉넴"
        }
        XCTAssertTrue(store.state.isNextEnabled)
        XCTAssertNil(store.state.lengthError)
    }

    func test_닉네임저장성공_델리게이트_전달() async {
        let requestedNickname = LockIsolated<String?>(nil)
        let requestedIconID = LockIsolated<Int?>(nil)
        let profile = self.profile
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "  둘픽  ",
                isTermsSheetPresented: false
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { nickname, iconID in
                requestedNickname.setValue(nickname)
                requestedIconID.setValue(iconID)
                return profile
            }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.success)
        await store.receive(\.nicknameSubmitFinished) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.nicknameConfirmed)

        XCTAssertEqual(requestedNickname.value, "둘픽")
        XCTAssertEqual(requestedIconID.value, 1)
    }

    func test_닉네임거절_인라인에러_노출() async {
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in throw ProfileError.invalidNickname }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.failure) {
            $0.isSubmitting = false
            $0.inlineError = "사용할 수 없는 닉네임이에요"
        }

        await store.send(\.binding.nickname, "둘픽이") {
            $0.nickname = "둘픽이"
            $0.inlineError = nil
        }
    }

    func test_인증실패_세션만료_델리게이트() async {
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in throw ProfileError.unauthorized }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.failure) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.sessionExpired)
    }

    func test_뒤로가기_델리게이트_전달_토스트정리() async {
        let store = TestStore(
            initialState: NicknameFeature.State(
                toast: .error("네트워크 연결을 확인해 주세요."),
                isTermsSheetPresented: false
            )
        ) {
            NicknameFeature()
        }

        await store.send(.backButtonTapped) {
            $0.toast = nil
        }
        await store.receive(\.delegate.back)
    }

    func test_한자입력_다음버튼_활성() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(\.binding.nickname, "둘") {
            $0.nickname = "둘"
        }
        XCTAssertTrue(store.state.isNextEnabled)
        XCTAssertNil(store.state.lengthError)
    }

    func test_제출중_뒤로가기_무시() async {
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isSubmitting: true,
                isTermsSheetPresented: false
            )
        ) {
            NicknameFeature()
        }

        await store.send(.backButtonTapped)
    }
}

// 약관 개별 동의는 케이스가 많아 별도 클래스로 둔다. type_body_length 한계 때문이다
@MainActor
final class NicknameTermsAgreementTests: XCTestCase {
    // MARK: - 약관 개별 동의

    func test_체크누르기_켜짐_다시누르면_꺼짐() async {
        let store = TestStore(initialState: NicknameFeature.State()) {
            NicknameFeature()
        }

        await store.send(.termsCheckTapped(.service)) {
            $0.agreedTerms = [.service]
        }
        await store.send(.termsCheckTapped(.service)) {
            $0.agreedTerms = []
        }
    }

    func test_전부꺼짐_버튼문구_모두동의하기() {
        let state = NicknameFeature.State()

        XCTAssertEqual(state.termsAgreeButtonTitle, "모두 동의하기")
    }

    func test_필수둘켜짐_버튼문구_완료() {
        let state = NicknameFeature.State(agreedTerms: [.service, .privacy])

        XCTAssertEqual(state.termsAgreeButtonTitle, "완료")
    }

    func test_필수하나만켜짐_버튼문구_모두동의하기() {
        let state = NicknameFeature.State(agreedTerms: [.service])

        XCTAssertEqual(state.termsAgreeButtonTitle, "모두 동의하기")
    }

    func test_마케팅만켜짐_버튼문구_모두동의하기() {
        let state = NicknameFeature.State(agreedTerms: [.marketing])

        XCTAssertEqual(state.termsAgreeButtonTitle, "모두 동의하기")
    }

    func test_전부꺼짐_버튼누름_셋다켜지고_시트닫힘() async {
        let store = TestStore(initialState: NicknameFeature.State()) {
            NicknameFeature()
        }

        XCTAssertTrue(store.state.isTermsSheetPresented)

        await store.send(.termsAgreeButtonTapped) {
            $0.agreedTerms = [.service, .privacy, .marketing]
            $0.isTermsSheetPresented = false
        }
    }

    func test_필수둘만켜짐_버튼누름_마케팅꺼진채_시트닫힘() async {
        let store = TestStore(
            initialState: NicknameFeature.State(agreedTerms: [.service, .privacy])
        ) {
            NicknameFeature()
        }

        await store.send(.termsAgreeButtonTapped) {
            $0.isTermsSheetPresented = false
        }

        XCTAssertFalse(store.state.agreedTerms.contains(.marketing))
    }
}

// 위 클래스가 type_body_length 한계라 마케팅 알림 케이스는 따로 둔다
@MainActor
final class NicknameMarketingNotificationTests: XCTestCase {
    private let profile = UserProfile(
        nickname: "둘픽",
        iconID: 1,
        datePreference: nil
    )

    /// 온보딩 시점의 서버 값. 마케팅은 꺼져 있고 동의한 버전이 없다
    private static let loadedSettings = NotificationSettings(
        contentSavedEnabled: true,
        dateScheduleEnabled: false,
        marketingEnabled: false,
        marketingConsentVersion: nil,
        availableMarketingConsentVersion: "v1"
    )

    // MARK: - 마케팅 동의와 알림 설정

    func test_마케팅동의_닉네임제출_조회후변경_순서대로호출() async {
        let calls = LockIsolated<[String]>([])
        let sent = LockIsolated<NotificationSettings?>(nil)
        let profile = self.profile
        let loaded = Self.loadedSettings
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false,
                agreedTerms: [.service, .privacy, .marketing]
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in profile }
            $0.profileClient.notificationSettings = {
                calls.withValue { $0.append("load") }
                return loaded
            }
            $0.profileClient.updateNotificationSettings = { settings in
                calls.withValue { $0.append("update") }
                sent.setValue(settings)
                return settings
            }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.success)
        await store.receive(\.nicknameSubmitFinished) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.nicknameConfirmed)

        XCTAssertEqual(calls.value, ["load", "update"])
    }

    func test_마케팅동의_변경요청_마케팅켜짐_동의버전_조회값() async {
        let sent = LockIsolated<NotificationSettings?>(nil)
        let profile = self.profile
        let loaded = Self.loadedSettings
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false,
                agreedTerms: [.service, .privacy, .marketing]
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in profile }
            $0.profileClient.notificationSettings = { loaded }
            $0.profileClient.updateNotificationSettings = { settings in
                sent.setValue(settings)
                return settings
            }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.success)
        await store.receive(\.nicknameSubmitFinished) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.nicknameConfirmed)

        XCTAssertEqual(sent.value?.marketingEnabled, true)
        XCTAssertEqual(sent.value?.marketingConsentVersion, "v1")
        // 나머지 두 값은 조회 응답 그대로 되돌려 보낸다
        XCTAssertEqual(sent.value?.contentSavedEnabled, true)
        XCTAssertEqual(sent.value?.dateScheduleEnabled, false)
    }

    func test_마케팅미동의_닉네임제출_알림설정_호출없음() async {
        let calls = LockIsolated<[String]>([])
        let profile = self.profile
        let loaded = Self.loadedSettings
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false,
                agreedTerms: [.service, .privacy]
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in profile }
            $0.profileClient.notificationSettings = {
                calls.withValue { $0.append("load") }
                return loaded
            }
            $0.profileClient.updateNotificationSettings = { settings in
                calls.withValue { $0.append("update") }
                return settings
            }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.success)
        await store.receive(\.nicknameSubmitFinished) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.nicknameConfirmed)

        XCTAssertEqual(calls.value, [])
    }

    func test_알림설정조회실패_다음화면으로_진행() async {
        let profile = self.profile
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false,
                agreedTerms: [.service, .privacy, .marketing]
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in profile }
            $0.profileClient.notificationSettings = { throw ProfileError.unknown }
            $0.profileClient.updateNotificationSettings = { settings in
                XCTFail("조회가 실패하면 변경을 부르지 않는다")
                return settings
            }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.success)
        await store.receive(\.nicknameSubmitFinished) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.nicknameConfirmed)

        XCTAssertNil(store.state.toast)
    }

    func test_알림설정변경실패_다음화면으로_진행() async {
        let profile = self.profile
        let loaded = Self.loadedSettings
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false,
                agreedTerms: [.service, .privacy, .marketing]
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in profile }
            $0.profileClient.notificationSettings = { loaded }
            $0.profileClient.updateNotificationSettings = { _ in throw ProfileError.unknown }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.success)
        await store.receive(\.nicknameSubmitFinished) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.nicknameConfirmed)

        XCTAssertNil(store.state.toast)
    }

    func test_알림설정_도는동안_제출중_유지() async {
        let profile = self.profile
        let loaded = Self.loadedSettings
        let gate = AsyncStream.makeStream(of: Void.self)
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false,
                agreedTerms: [.service, .privacy, .marketing]
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in profile }
            $0.profileClient.notificationSettings = {
                for await _ in gate.stream { break }
                return loaded
            }
            $0.profileClient.updateNotificationSettings = { settings in settings }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.success)
        XCTAssertTrue(store.state.isSubmitting)

        await store.send(.backButtonTapped)
        await store.send(.nextButtonTapped)

        gate.continuation.finish()
        await store.receive(\.nicknameSubmitFinished) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.nicknameConfirmed)
    }

    func test_동의버전없음_변경요청_호출없음() async {
        let profile = self.profile
        let loaded = NotificationSettings(
            contentSavedEnabled: true,
            dateScheduleEnabled: false,
            marketingEnabled: false,
            marketingConsentVersion: nil,
            availableMarketingConsentVersion: nil
        )
        let store = TestStore(
            initialState: NicknameFeature.State(
                nickname: "둘픽",
                isTermsSheetPresented: false,
                agreedTerms: [.service, .privacy, .marketing]
            )
        ) {
            NicknameFeature()
        } withDependencies: {
            $0.profileClient.updateNickname = { _, _ in profile }
            $0.profileClient.notificationSettings = { loaded }
            $0.profileClient.updateNotificationSettings = { settings in
                XCTFail("동의 버전이 없으면 변경을 부르지 않는다")
                return settings
            }
        }

        await store.send(.nextButtonTapped) {
            $0.isSubmitting = true
        }
        await store.receive(\.updateNicknameResponse.success)
        await store.receive(\.nicknameSubmitFinished) {
            $0.isSubmitting = false
        }
        await store.receive(\.delegate.nicknameConfirmed)

        XCTAssertNil(store.state.toast)
    }
}
