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
        await store.receive(\.updateNicknameResponse.success) {
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

    func test_모두동의_시트_닫힘() async {
        let store = TestStore(initialState: NicknameFeature.State()) {
            NicknameFeature()
        }

        XCTAssertTrue(store.state.isTermsSheetPresented)

        await store.send(.termsAgreeButtonTapped) {
            $0.isTermsSheetPresented = false
        }
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
