import SharedDesignSystem
import SwiftUI

/// iOS 26 은 유리 재질, 그 아래는 회색 원으로 떨어진다
struct GlassCircleBackground: ViewModifier {
    // Domain.Content 와 이름이 겹쳐서 Self.Content 로 적는다
    func body(content: Self.Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content
                .background(Color.gray50)
                .clipShape(Circle())
        }
    }
}

extension View {
    func glassCircleBackground() -> some View {
        modifier(GlassCircleBackground())
    }
}
