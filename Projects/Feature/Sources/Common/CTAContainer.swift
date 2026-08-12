import SharedDesignSystem
import SwiftUI

// 사용법: CTAContainer { AppButton("다음", style: .dark, size: .xl, fullWidth: true) { } }
// 온보딩 화면 하단 공통 CTA 영역. 상단 36 그라데이션 + 버튼 컨테이너를 함께 그린다
struct CTAContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
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

// CTA 위에 토스트를 띄울 때 쓰는 치수. 화면마다 버튼 구성이 달라 숫자를 직접 박지 않는다.
// CTAContainer 는 제네릭이라 static 멤버를 타입 이름만으로 못 부르므로 별도 네임스페이스로 둔다
enum CTALayout {
    static let bottomPadding: CGFloat = 20
    static let buttonSpacing: CGFloat = 8
    static let toastGap: CGFloat = 18

    static let xlButtonHeight: CGFloat = 56
    static let textButtonHeight: CGFloat = 32

    /// 버튼 영역 높이를 받아 토스트 하단 여백을 만든다
    static func toastInset(contentHeight: CGFloat) -> CGFloat {
        bottomPadding + contentHeight + toastGap
    }

    /// 위에서부터 쌓인 버튼 높이들로 CTA 영역 높이를 계산해 토스트 하단 여백을 만든다
    static func toastInset(buttonHeights: [CGFloat]) -> CGFloat {
        let spacingCount = CGFloat(max(buttonHeights.count - 1, 0))
        let contentHeight = buttonHeights.reduce(0, +) + buttonSpacing * spacingCount
        return toastInset(contentHeight: contentHeight)
    }
}
