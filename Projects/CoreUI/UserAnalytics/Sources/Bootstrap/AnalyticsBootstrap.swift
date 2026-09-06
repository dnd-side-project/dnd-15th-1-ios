import SharedLogger
import ThirdPartyUI

/// 클라리티 세션 녹화 초기화.
///
/// App 이 앱 시작 때 한 번 부른다. SDK 를 아는 것은 이 모듈뿐이다
public enum AnalyticsBootstrap {
    @MainActor
    public static func run(projectID: String) {
        guard isEnabled(projectID: projectID) else {
            Logger.shared.info("클라리티 프로젝트 ID 가 비어 초기화를 건너뛴다", category: .app)
            return
        }

        let config = ClarityConfig(projectId: projectID)
        let didStart = ClaritySDK.initialize(config: config)
        if !didStart {
            Logger.shared.error("클라리티 초기화에 실패했다", category: .app)
        }
    }

    /// 프로젝트 ID 가 실제 값인지 가른다. 공백만 있는 값은 빈 값으로 본다
    static func isEnabled(projectID: String) -> Bool {
        !projectID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
