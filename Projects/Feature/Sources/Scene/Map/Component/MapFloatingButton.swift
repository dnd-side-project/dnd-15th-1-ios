import SharedDesignSystem
import SwiftUI

// MARK: - MapFloatingMetric

private enum MapFloatingMetric {
    static let height: CGFloat = 40
    static let iconSize: CGFloat = 24
    static let pillCornerRadius: CGFloat = 12
}

// MARK: - MapFloatingButton

/// 지도 위에 떠 있는 버튼. 원형과 알약 두 모양이다.
///
/// ```swift
/// MapFloatingButton(icon: .locate) { }                 // 원형
/// MapFloatingButton(title: "데이트 코스 짜러가기") { }    // 알약
/// ```
///
/// 위치는 잡지 않는다. 시트 위에 띄우려면 `MapBottomSheet` 의 `above` 자리에 담는다.
struct MapFloatingButton: View {

    private enum Shape {
        case circle(icon: Image)
        case pill(title: String)
    }

    private let shape: Shape
    private let action: () -> Void

    /// 아이콘만 있는 원형. 흰 바탕이다 (a08 우하단 현재위치).
    init(icon: Image, action: @escaping () -> Void) {
        self.shape = .circle(icon: icon)
        self.action = action
    }

    /// 글자만 있는 알약. 빨강 바탕이다 (a08 좌하단 `데이트 코스 짜러가기`).
    init(title: String, action: @escaping () -> Void) {
        self.shape = .pill(title: title)
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Label

private extension MapFloatingButton {

    @ViewBuilder
    var label: some View {
        switch shape {
        case let .circle(icon):
            circleLabel(icon: icon)

        case let .pill(title):
            pillLabel(title: title)
        }
    }

    func circleLabel(icon: Image) -> some View {
        self.icon(icon, tint: .textPrimary)
            .frame(width: MapFloatingMetric.height, height: MapFloatingMetric.height)
            .background(Color.commonWhite, in: Circle())
    }

    func pillLabel(title: String) -> some View {
        Text(title)
            .typography(.body1M)
            .foregroundStyle(Color.textInverse)
            .padding(.horizontal, Spacing.s20)
            .frame(height: MapFloatingMetric.height)
            .background(
                Color.brandPrimary,
                in: RoundedRectangle(cornerRadius: MapFloatingMetric.pillCornerRadius)
            )
    }

    func icon(_ image: Image, tint: Color) -> some View {
        image
            .renderingMode(.template)
            .resizable()
            .frame(width: MapFloatingMetric.iconSize, height: MapFloatingMetric.iconSize)
            .foregroundStyle(tint)
    }
}

#if DEBUG

// MARK: - Preview

// a08 — 좌하단 알약과 우하단 원형
#Preview("지도 위 버튼") {
    ZStack {
        Color.gray200
            .ignoresSafeArea()

        HStack(spacing: Spacing.s12) {
            MapFloatingButton(title: "데이트 코스 짜러가기") {}
            Spacer(minLength: Spacing.s12)
            MapFloatingButton(icon: .locate) {}
        }
        .padding(.horizontal, Spacing.s20)
    }
}

#endif
