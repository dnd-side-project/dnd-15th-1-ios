/// 믹스패널이 초기화됐는지를 이 모듈 안에서 나눠 본다.
///
/// 켜짐 여부를 모듈이 직접 들고 있어야 한다. SDK 는 초기화 전에 인스턴스를 부르면
/// 빈 토큰에 자동 이벤트를 켠 인스턴스를 만들어 버린다
@MainActor
enum AnalyticsRuntime {
    private(set) static var isEnabled = false

    /// `AnalyticsBootstrap` 이 초기화에 성공한 뒤에만 부른다
    static func enable() {
        isEnabled = true
    }
}
