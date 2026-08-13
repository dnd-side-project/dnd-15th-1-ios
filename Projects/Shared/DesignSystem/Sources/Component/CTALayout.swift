import SwiftUI

// CTA 위에 토스트를 띄울 때 쓰는 치수. 화면마다 버튼 구성이 달라 숫자를 직접 박지 않는다.
// CTAContainer 는 제네릭이라 static 멤버를 타입 이름만으로 못 부르므로 별도 네임스페이스로 둔다
public enum CTALayout {
    public static let bottomPadding: CGFloat = 20
    public static let buttonSpacing: CGFloat = 8
    public static let toastGap: CGFloat = 18

    public static let xlButtonHeight: CGFloat = 56
    public static let textButtonHeight: CGFloat = 32

    /// 버튼 영역 높이를 받아 토스트 하단 여백을 만든다
    public static func toastInset(contentHeight: CGFloat) -> CGFloat {
        bottomPadding + contentHeight + toastGap
    }

    /// 위에서부터 쌓인 버튼 높이들로 CTA 영역 높이를 계산해 토스트 하단 여백을 만든다
    public static func toastInset(buttonHeights: [CGFloat]) -> CGFloat {
        let spacingCount = CGFloat(max(buttonHeights.count - 1, 0))
        let contentHeight = buttonHeights.reduce(0, +) + buttonSpacing * spacingCount
        return toastInset(contentHeight: contentHeight)
    }
}
