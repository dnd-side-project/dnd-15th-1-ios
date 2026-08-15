import SharedDesignSystem
import SwiftUI

// MARK: - TimeWheelPicker

/// 오전·오후 / 시 / 분 3열 휠 피커. 시안: `c10`
///
/// 구조는 `DateWheelPicker` 와 같다. 치수·선택 바·열은 `WheelMetrics` · `WheelSelectionBar` ·
/// `WheelColumn`(`WheelPicker.swift`)을 나눠 쓴다. 여기는 단위 글자가 없고 안쪽 여백도 없다.
///
/// 딤 · 하단 시트 껍데기 · `확인` 버튼은 감싸는 쪽이 만든다. 여기는 휠 영역(높이 264)까지다.
/// `selection` 에는 `hour`(0...23) · `minute` 만 쓴다. 나머지 필드는 받은 그대로 둔다.
public struct TimeWheelPicker: View {

    /// 12시간제 표시 순서. 12 가 맨 위다.
    private static let hours: [Int] = [12] + Array(1...11)

    @Binding private var selection: DateComponents
    private let minuteStep: Int

    public init(selection: Binding<DateComponents>, minuteStep: Int) {
        self._selection = selection
        self.minuteStep = minuteStep
    }

    public var body: some View {
        ZStack {
            WheelSelectionBar()

            HStack(spacing: WheelMetrics.columnSpacing) {
                WheelColumn(items: DayPeriod.allCases, selection: periodBinding) { $0.title }
                WheelColumn(items: Self.hours, selection: hourBinding, title: Self.twoDigits)
                WheelColumn(items: minutes, selection: minuteBinding, title: Self.twoDigits)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: WheelMetrics.areaHeight)
        // 첫 표시(`initial`)뿐 아니라 밖에서 `selection` 을 갈아끼운 뒤에도 돌려야
        // 휠에 보이는 값과 바인딩 값이 어긋난 채로 남지 않는다.
        .onChange(of: selection, initial: true) { _, _ in normalizeSelection() }
    }

    // MARK: Binding

    private var periodBinding: Binding<DayPeriod?> {
        Binding(
            get: { resolvedPeriod },
            set: { newValue in
                guard let newValue else { return }
                update(period: newValue, hour: resolvedHour, minute: resolvedMinute)
            }
        )
    }

    private var hourBinding: Binding<Int?> {
        Binding(
            get: { resolvedHour },
            set: { newValue in
                guard let newValue else { return }
                update(period: resolvedPeriod, hour: newValue, minute: resolvedMinute)
            }
        )
    }

    private var minuteBinding: Binding<Int?> {
        Binding(
            get: { resolvedMinute },
            set: { newValue in
                guard let newValue else { return }
                update(period: resolvedPeriod, hour: resolvedHour, minute: newValue)
            }
        )
    }

    // MARK: Value

    /// 1 미만이거나 60을 넘는 간격은 1분으로 본다.
    private var resolvedStep: Int {
        (1...60).contains(minuteStep) ? minuteStep : 1
    }

    private var minutes: [Int] {
        Array(stride(from: 0, to: 60, by: resolvedStep))
    }

    private var resolvedHour24: Int {
        min(max(selection.hour ?? 0, 0), 23)
    }

    private var resolvedPeriod: DayPeriod {
        resolvedHour24 < 12 ? .am : .pm
    }

    /// 12시간제 시각. 0시와 12시는 둘 다 `12` 로 보인다.
    private var resolvedHour: Int {
        let hour = resolvedHour24 % 12
        return hour == 0 ? 12 : hour
    }

    /// 간격에 없는 분은 바로 아래 눈금으로 내린다.
    private var resolvedMinute: Int {
        let minute = min(max(selection.minute ?? 0, 0), 59)
        return minutes.last(where: { $0 <= minute }) ?? 0
    }

    /// 빈 필드나 간격에 없는 분을 들고 들어온 경우 밖의 값도 휠이 보여주는 값으로 맞춰준다.
    ///
    /// 이미 맞으면 아무것도 쓰지 않아 `onChange` 가 스스로를 다시 불러 되먹임하는 일이 없다.
    private func normalizeSelection() {
        let hour = resolvedHour24
        let minute = resolvedMinute

        guard selection.hour != hour || selection.minute != minute else {
            return
        }

        update(period: resolvedPeriod, hour: resolvedHour, minute: minute)
    }

    private func update(period: DayPeriod, hour: Int, minute: Int) {
        var components = selection
        components.hour = (hour % 12) + (period == .pm ? 12 : 0)
        components.minute = minute
        selection = components
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

// MARK: - DayPeriod

private enum DayPeriod: Int, CaseIterable, Hashable {
    case am
    case pm

    var title: String {
        switch self {
        case .am: "오전"
        case .pm: "오후"
        }
    }
}

// MARK: - Preview

// 시안: c10
#Preview("시간") {
    @Previewable @State var selection = DateComponents(hour: 13, minute: 10)

    VStack(spacing: Spacing.s16) {
        TimeWheelPicker(selection: $selection, minuteStep: 5)

        Text("\(selection.hour ?? 0)시 \(selection.minute ?? 0)분")
            .typography(.caption1R)
            .foregroundStyle(Color.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
}

// 간격이 인자인지 확인용. 1분 간격이면 분 휠이 00...59 로 늘어난다.
#Preview("1분 간격") {
    @Previewable @State var selection = DateComponents(hour: 9, minute: 7)

    VStack(spacing: Spacing.s16) {
        TimeWheelPicker(selection: $selection, minuteStep: 1)

        Text("\(selection.hour ?? 0)시 \(selection.minute ?? 0)분")
            .typography(.caption1R)
            .foregroundStyle(Color.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
}
