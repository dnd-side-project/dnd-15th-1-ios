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

    func test_공백만입력_다음버튼_비활성() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(.nicknameChanged("   ")) {
            $0.nickname = "   "
        }
        XCTAssertFalse(store.state.isNextEnabled)
        XCTAssertNil(store.state.lengthError)
    }

    func test_일곱자입력_에러문구_노출() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(.nicknameChanged("일곱글자닉네임")) {
            $0.nickname = "일곱글자닉네임"
        }
        XCTAssertEqual(store.state.lengthError, "최대 6글자 내로 입력해주세요")
        XCTAssertFalse(store.state.isNextEnabled)
    }

    func test_여섯자입력_다음버튼_활성() async {
        let store = TestStore(initialState: NicknameFeature.State(isTermsSheetPresented: false)) {
            NicknameFeature()
        }

        await store.send(.nicknameChanged("여섯글자닉넴")) {
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

        await store.send(.nicknameChanged("둘픽이")) {
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

    func test_약관두개동의_시트_닫힘() async {
        let store = TestStore(initialState: NicknameFeature.State()) {
            NicknameFeature()
        }

        XCTAssertTrue(store.state.isTermsSheetPresented)

        await store.send(.termsToggled(.service)) {
            $0.agreedTerms = [.service]
        }
        XCTAssertFalse(store.state.isTermsAgreeEnabled)

        await store.send(.termsAgreeButtonTapped)

        await store.send(.termsToggled(.privacy)) {
            $0.agreedTerms = [.service, .privacy]
        }
        XCTAssertTrue(store.state.isTermsAgreeEnabled)

        await store.send(.termsAgreeButtonTapped) {
            $0.isTermsSheetPresented = false
        }
    }
}
