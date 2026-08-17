@testable import Feature
import ThirdParty
import XCTest

final class FeatureLogTests: XCTestCase {
    func test_씬이름_Feature접미_제거() {
        XCTAssertEqual(FeatureLog.sceneName(from: "AuthFeature"), "Auth")
        XCTAssertEqual(FeatureLog.sceneName(from: "RootFlowFeature"), "RootFlow")
        XCTAssertEqual(FeatureLog.sceneName(from: "MainTabFeature"), "MainTab")
        XCTAssertEqual(FeatureLog.sceneName(from: "SearchFeature"), "Search")
        XCTAssertEqual(FeatureLog.sceneName(from: "Root"), "Root")
    }

    func test_오퍼레이션이름_Response접미_제거() {
        XCTAssertEqual(FeatureLog.operationName(fromActionName: "loginResponse"), "login")
        XCTAssertEqual(FeatureLog.operationName(fromActionName: "logoutResponse"), "logout")
        XCTAssertEqual(FeatureLog.operationName(fromActionName: "sessionRestored"), "restoreSession")
        XCTAssertEqual(FeatureLog.operationName(fromActionName: "contentsResponse"), "contents")
    }

    func test_메시지형식_액션_상태_화면이동_오류() {
        XCTAssertEqual(
            FeatureLog.actionMessage(scene: "Auth", name: "loginButtonTapped", payload: "provider=apple"),
            "[Feature] [Auth] 사용자 액션: loginButtonTapped(provider=apple)"
        )
        XCTAssertEqual(
            FeatureLog.stateMessage(scene: "Auth", field: "isLoading", from: "false", to: "true"),
            "[Feature] [Auth] 상태 변경: isLoading(false → true)"
        )
        XCTAssertEqual(
            FeatureLog.navigationMessage(scene: "RootFlow", field: "phase", from: "bootstrapping", to: "mainTab"),
            "[Feature] [RootFlow] 화면 이동: phase(bootstrapping → mainTab)"
        )
        XCTAssertEqual(
            FeatureLog.errorMessage(
                scene: "Auth",
                operation: "login",
                error: "network",
                userVisible: true
            ),
            "[Feature] [Auth] 오류: login(network, userVisible=true)"
        )
    }

    func test_값요약_구조체_타입이름만() {
        struct ToastLikeState: Equatable {
            var message = "로그인에 실패했습니다."
            var icon: String?
            var actionTitle: String?
        }

        final class SessionLikeBox {
            var email = "user@example.com"
        }

        // struct: 내부 프로퍼티 dump 금지, 타입 이름만
        let toast = FeatureLog.summarizeValue(ToastLikeState())
        XCTAssertEqual(toast, "ToastLikeState")
        XCTAssertFalse(toast.contains("message"))
        XCTAssertFalse(toast.contains("로그인에 실패했습니다."))

        // Optional 언래핑 후에도 타입 이름만
        let presentToast: ToastLikeState? = ToastLikeState()
        XCTAssertEqual(FeatureLog.summarizeValue(presentToast), "ToastLikeState")
        XCTAssertEqual(FeatureLog.summarizeValue(ToastLikeState?.none), "nil")

        // class 도 동일
        let boxed = FeatureLog.summarizeValue(SessionLikeBox())
        XCTAssertEqual(boxed, "SessionLikeBox")
        XCTAssertFalse(boxed.contains("user@example.com"))

        // 기존 특수 처리 유지: String / Bool / 숫자 / 컬렉션
        XCTAssertEqual(FeatureLog.summarizeValue("cafe"), "cafe")
        XCTAssertEqual(FeatureLog.summarizeValue(true), "true")
        XCTAssertEqual(FeatureLog.summarizeValue(false), "false")
        XCTAssertEqual(FeatureLog.summarizeValue(3), "3")
        XCTAssertEqual(FeatureLog.summarizeValue([1, 2, 3]), "3 items")
        XCTAssertEqual(FeatureLog.summarizeValue(["a": 1]), "1 items")
    }

    func test_마스킹_토큰_가림() {
        let input = "accessToken=aaa refreshToken=bbb Authorization=Bearer ccc identityToken=ddd"
        let redacted = FeatureLog.redact(input)
        XCTAssertFalse(redacted.contains("aaa"))
        XCTAssertFalse(redacted.contains("bbb"))
        XCTAssertFalse(redacted.contains("ccc"))
        XCTAssertFalse(redacted.contains("ddd"))
        XCTAssertTrue(redacted.contains("[REDACTED]"))
    }
}
