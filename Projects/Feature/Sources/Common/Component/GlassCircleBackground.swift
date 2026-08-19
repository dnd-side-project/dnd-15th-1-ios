import SharedDesignSystem
import SwiftUI

/// iOS 26 은 유리 재질, 그 아래는 회색 원으로 떨어진다
struct GlassCircleBackground: ViewModifier {
    // Domain.Content 와 이름이 겹쳐서 Self.Content 로 적는다
    @ViewBuilder
    func body(content: Self.Content) -> some View {
        // `#available` 은 런타임 검사라 SDK 에 심볼이 없으면 컴파일이 깨진다.
        // CI 의 Xcode 16.4 에는 `glassEffect` 가 없어 컴파일 조건으로 한 번 더 가른다
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            plainCircle(content)
        }
        #else
        plainCircle(content)
        #endif
    }

    private func plainCircle(_ content: Self.Content) -> some View {
        content
            .background(Color.gray50)
            .clipShape(Circle())
    }
}

extension View {
    func glassCircleBackground() -> some View {
        modifier(GlassCircleBackground())
    }
}
