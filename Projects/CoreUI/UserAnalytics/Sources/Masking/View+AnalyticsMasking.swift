import SwiftUI
import ThirdPartyUI

public extension View {
    /// 이 뷰의 내용을 녹화에서 가린다. 가려진 내용은 서버로 올라가지 않는다
    func analyticsMasked() -> some View {
        clarityMask()
    }

    /// `isMasked` 가 참일 때만 녹화에서 가린다
    func analyticsMasked(_ isMasked: Bool) -> some View {
        modifier(AnalyticsConditionalMask(isMasked: isMasked))
    }

    /// 가려진 뷰 안에서 이 부분만 녹화되게 한다
    func analyticsUnmasked() -> some View {
        clarityUnmask()
    }
}

private struct AnalyticsConditionalMask: ViewModifier {
    let isMasked: Bool

    func body(content: Content) -> some View {
        if isMasked {
            content.analyticsMasked()
        } else {
            content
        }
    }
}
