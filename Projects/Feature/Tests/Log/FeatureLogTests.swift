@testable import Feature
import ThirdParty
import XCTest

final class FeatureLogTests: XCTestCase {
    func test_씬이름_Feature접미_제거() {
        XCTAssertEqual(FeatureLog.sceneName(from: "AuthFeature"), "Auth")
        XCTAssertEqual(FeatureLog.sceneName(from: "AppCoordinatorFeature"), "AppCoordinator")
        XCTAssertEqual(FeatureLog.sceneName(from: "MainTabFeature"), "MainTab")
        XCTAssertEqual(FeatureLog.sceneName(from: "SearchFeature"), "Search")
        XCTAssertEqual(FeatureLog.sceneName(from: "Root"), "Root")
    }

    func test_오퍼레이션이름_Response접미_제거() {
        XCTAssertEqual(FeatureLog.operationName(fromActionName: "loginResponse"), "login")
        XCTAssertEqual(FeatureLog.operationName(fromActionName: "logoutResponse"), "logout")
        XCTAssertEqual(FeatureLog.operationName(fromActionName: "sessionRestored"), "restoreSession")
        XCTAssertEqual(FeatureLog.operationName(fromActionName: "popularPostsResponse"), "popularPosts")
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
            FeatureLog.navigationMessage(scene: "AppCoordinator", field: "phase", from: "bootstrapping", to: "main"),
            "[Feature] [AppCoordinator] 화면 이동: phase(bootstrapping → main)"
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
