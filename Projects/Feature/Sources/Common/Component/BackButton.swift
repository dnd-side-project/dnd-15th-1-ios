import SharedDesignSystem
import SwiftUI

// MARK: - BackButtonMetric

enum BackButtonMetric {
    /// 뒤로가기 버튼 왼쪽 여백
    static let leadingInset: CGFloat = Spacing.s16
    static let buttonSize: CGFloat = 44
    static let iconSize: CGFloat = 24
}

// MARK: - BackButton

/// 툴바가 아닌 자리에 직접 얹는 뒤로가기 버튼. 유리 원형 배경을 스스로 붙인다
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image.arrowLeft
                .renderingMode(.template)
                .resizable()
                .frame(width: BackButtonMetric.iconSize, height: BackButtonMetric.iconSize)
                .foregroundStyle(Color.textSecondary)
                .frame(width: BackButtonMetric.buttonSize, height: BackButtonMetric.buttonSize)
        }
        .buttonStyle(.plain)
        .glassCircleBackground()
    }
}

// MARK: - BackToolbarItem

/// 툴바 왼쪽에 서는 뒤로가기 버튼. 유리 배경은 iOS 26 이 붙인다
struct BackToolbarItem: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: action) {
                Image.arrowLeft
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: BackButtonMetric.iconSize, height: BackButtonMetric.iconSize)
                    .foregroundStyle(Color.textSecondary)
            }
        }
    }
}
