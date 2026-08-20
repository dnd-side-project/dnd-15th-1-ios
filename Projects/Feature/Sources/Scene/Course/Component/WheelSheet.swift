import SharedDesignSystem
import SwiftUI

// MARK: - WheelSheet Metric

private enum WheelSheetMetric {
    static let wheelVerticalPadding: CGFloat = Spacing.s24
    static let buttonHorizontalPadding: CGFloat = Spacing.s20
    static let buttonBottomPadding: CGFloat = Spacing.s16
}

// MARK: - WheelSheet

/// `.bottomSheet(showsHandle: false)` 가 올리는 휠 내용 뷰. 휠 슬롯과 `확인` 버튼을 그린다.
///
/// 휠 부품(`DateWheelPicker` · `TimeWheelPicker`)은 휠만 그린다. 딤·흰 판·모서리는 BottomSheet 가 맡는다.
///
/// ```swift
/// WheelSheet(onConfirm: { ... }) {
///     DateWheelPicker(selection: $draft, yearRange: 2024 ... 2034)
/// }
/// ```
struct WheelSheet<Content: View>: View {
    private let onConfirm: () -> Void
    private let content: Content

    init(onConfirm: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onConfirm = onConfirm
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.vertical, WheelSheetMetric.wheelVerticalPadding)

            AppButton("확인", style: .dark, size: .xl, fullWidth: true) {
                onConfirm()
            }
            .padding(.horizontal, WheelSheetMetric.buttonHorizontalPadding)
            .padding(.bottom, WheelSheetMetric.buttonBottomPadding)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG

// MARK: - Preview

private struct WheelSheetPreviewHost: View {
    @State private var date = DateComponents(year: 2026, month: 1, day: 22)
    @State private var time = DateComponents(hour: 13, minute: 10)
    @State private var isPresented = true
    let showsTime: Bool

    var body: some View {
        Color.gray200
            .ignoresSafeArea()
            .bottomSheet(isPresented: $isPresented, showsHandle: false) {
                WheelSheet(onConfirm: { isPresented = false }) {
                    if showsTime {
                        TimeWheelPicker(selection: $time, minuteStep: 5)
                    } else {
                        DateWheelPicker(selection: $date, yearRange: 2024 ... 2034)
                    }
                }
            }
    }
}

// c09 — 날짜 휠
#Preview("날짜") {
    WheelSheetPreviewHost(showsTime: false)
}

// c10 — 시간 휠
#Preview("시간") {
    WheelSheetPreviewHost(showsTime: true)
}

#endif
