import SharedDesignSystem
import SwiftUI

// MARK: - MapFloatingMetric

private enum MapFloatingMetric {
    static let height: CGFloat = 40
    static let iconSize: CGFloat = 20
    static let shadowRadius: CGFloat = 8
    static let shadowOpacity: CGFloat = 0.10
    static let shadowOffsetY: CGFloat = 2

    /// 버튼 아래 끝과 시트 윗면 사이. a08 · b04 에서 잰 값이다.
    static let gapAboveSheet: CGFloat = 16
}

// MARK: - MapFloatingButton

/// 지도 위에 떠 있는 버튼. 원형과 알약 두 모양이다.
///
/// ```swift
/// MapFloatingButton(icon: .locate) { }                 // 원형
/// MapFloatingButton(title: "데이트 코스 짜러가기") { }    // 알약
/// ```
///
/// 위치는 잡지 않는다. 시트 위에 띄우려면 `MapFloatingControls` 에 담는다.
public struct MapFloatingButton: View {

    private enum Shape {
        case circle(icon: Image)
        case pill(title: String)
    }

    private let shape: Shape
    private let action: () -> Void

    /// 아이콘만 있는 원형. 흰 바탕이다 (a08 우하단 현재위치).
    public init(icon: Image, action: @escaping () -> Void) {
        self.shape = .circle(icon: icon)
        self.action = action
    }

    /// 글자만 있는 알약. 빨강 바탕이다 (a08 좌하단 `데이트 코스 짜러가기`).
    public init(title: String, action: @escaping () -> Void) {
        self.shape = .pill(title: title)
        self.action = action
    }

    public var body: some View {
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

    // 그림자는 원형에만 건다. 시안의 알약은 평평하다.
    func circleLabel(icon: Image) -> some View {
        self.icon(icon, tint: .textPrimary)
            .frame(width: MapFloatingMetric.height, height: MapFloatingMetric.height)
            .background(Color.commonWhite, in: Circle())
            .shadow(
                color: Color.commonBlack.opacity(MapFloatingMetric.shadowOpacity),
                radius: MapFloatingMetric.shadowRadius,
                y: MapFloatingMetric.shadowOffsetY
            )
    }

    func pillLabel(title: String) -> some View {
        Text(title)
            .typography(.body1SB)
            .foregroundStyle(Color.textInverse)
            .padding(.horizontal, Spacing.s20)
            .frame(height: MapFloatingMetric.height)
            .background(Color.brandPrimary, in: Capsule())
    }

    func icon(_ image: Image, tint: Color) -> some View {
        image
            .renderingMode(.template)
            .resizable()
            .frame(width: MapFloatingMetric.iconSize, height: MapFloatingMetric.iconSize)
            .foregroundStyle(tint)
    }
}

// MARK: - MapFloatingControls

/// 지도 위 버튼을 바텀시트 바로 위에 띄우는 층.
///
/// 시트 높이를 값으로 받아 그만큼 띄운다. `MapBottomSheet` 와 같은 `ZStack` 에 얹어
/// `onHeightChange` 로 받은 높이를 그대로 넘기면 시트를 끌 때 버튼이 따라 움직인다.
///
/// ```swift
/// ZStack(alignment: .bottom) {
///     MapView()
///     MapFloatingControls(sheetHeight: sheetHeight) {
///         MapFloatingButton(title: "데이트 코스 짜러가기") { }
///     } trailing: {
///         MapFloatingButton(icon: .locate) { }
///     }
///     MapBottomSheet(detents: detents, selection: $detent) { sheetHeight = $0 } content: { ... }
/// }
/// ```
public struct MapFloatingControls<Leading: View, Trailing: View>: View {

    // 버튼이 아니라 이 층이 좌표를 안다.
    // 시안의 20 여백과 시트 위 16 간격이 호출부마다 흩어지지 않게 한다.
    private let sheetHeight: CGFloat
    private let leading: Leading
    private let trailing: Trailing

    public init(
        sheetHeight: CGFloat,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.sheetHeight = sheetHeight
        self.leading = leading()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: Spacing.s12) {
            leading
            Spacer(minLength: Spacing.s12)
            trailing
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.bottom, sheetHeight + MapFloatingMetric.gapAboveSheet)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

public extension MapFloatingControls where Leading == EmptyView {

    /// 오른쪽 버튼만 두는 경우 (b04 장소 고르기).
    init(sheetHeight: CGFloat, @ViewBuilder trailing: () -> Trailing) {
        self.init(sheetHeight: sheetHeight, leading: { EmptyView() }, trailing: trailing)
    }
}

// MARK: - Preview

private struct MapFloatingButtonPreviewHost<Controls: View>: View {
    let controls: (CGFloat) -> Controls

    @State private var selection: SheetDetent = .fraction(0.5)
    @State private var sheetHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // 지도 자리. SDK 를 붙이지 않는다
            Color.gray200
                .ignoresSafeArea()

            controls(sheetHeight)

            MapBottomSheet(
                detents: [.fraction(0.5), .fraction(0.13)],
                selection: $selection,
                onHeightChange: { sheetHeight = $0 }
            ) {
                VStack(alignment: .leading, spacing: Spacing.s12) {
                    Text("저장한 장소")
                        .typography(.title3SB)
                        .foregroundStyle(Color.textPrimary)

                    Text("시트 높이 \(Int(sheetHeight))")
                        .typography(.caption1M)
                        .foregroundStyle(Color.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Spacing.s20)
            }
        }
    }
}

// a08 — 시트를 끌면 두 버튼이 같이 오르내린다
#Preview("지도 기본") {
    MapFloatingButtonPreviewHost { sheetHeight in
        MapFloatingControls(sheetHeight: sheetHeight) {
            MapFloatingButton(title: "데이트 코스 짜러가기") {}
        } trailing: {
            MapFloatingButton(icon: .locate) {}
        }
    }
}

// b04 — 장소 고르기에서는 현재위치 버튼만 뜬다
#Preview("현재위치만") {
    MapFloatingButtonPreviewHost { sheetHeight in
        MapFloatingControls(sheetHeight: sheetHeight) {
            MapFloatingButton(icon: .locate) {}
        }
    }
}
