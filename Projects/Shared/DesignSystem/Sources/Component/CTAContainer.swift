import SwiftUI

// 사용법: CTAContainer { AppButton("다음", style: .dark, size: .xl, fullWidth: true) { } }
// 온보딩 화면 하단 공통 CTA 영역. 상단 36 그라데이션 + 버튼 컨테이너를 함께 그린다
public struct CTAContainer<Content: View>: View {
    @ViewBuilder private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        VStack(spacing: 0) {
            topGradient

            VStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .background(Color.bgDefault)
        }
    }

    private var topGradient: some View {
        LinearGradient(
            colors: [Color.bgDefault.opacity(0), Color.bgDefault],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 36)
        .allowsHitTesting(false)
    }
}
