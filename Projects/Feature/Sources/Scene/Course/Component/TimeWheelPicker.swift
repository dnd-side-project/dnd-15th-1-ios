import SharedDesignSystem
import SwiftUI

// MARK: - TimeWheelPicker

/// 오전·오후 / 시 / 분 3열 휠 피커. 시안: `c10`
///
/// 구조는 `DateWheelPicker` 와 같다. 치수·선택 바·열은 `WheelMetrics` · `WheelSelectionBar` ·
/// `WheelColumn`(`WheelColumn.swift`)을 나눠 쓴다. 여기는 단위 글자가 없고 안쪽 여백도 없다.
///
/// 딤 · 하단 시트 껍데기 · `확인` 버튼은 감싸는 쪽이 만든다. 여기는 휠 영역(높이 264)까지다.
/// `selection` 에는 `hour`(0...23) · `minute` 만 쓴다. 나머지 필드는 받은 그대로 둔다.
struct TimeWheelPicker: View {

    @Binding private var selection: DateComponents
    private let range: WheelTimeRange

    init(
        selection: Binding<DateComponents>,
        minuteStep: Int,
        minimum: DateComponents? = nil
    ) {
        self._selection = selection
        self.range = WheelTimeRange(minuteStep: minuteStep, minimum: minimum)
    }

    var body: some View {
        let resolved = range.resolved(selection)
        let period = period(of: resolved)
        let hour = hour12(of: resolved)
        let minutes = range.minutes(period: period, hour: hour)

        ZStack {
            WheelSelectionBar()

            HStack(spacing: WheelMetrics.columnSpacing) {
                WheelColumn(items: range.periods, selection: periodBinding) { $0.title }
                WheelColumn(
                    items: range.hours(period: period),
                    selection: hourBinding,
                    title: WheelFormat.twoDigits
                )
                WheelColumn(items: minutes, selection: minuteBinding, title: WheelFormat.twoDigits)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: WheelMetrics.areaHeight)
        // 첫 표시(`initial`)뿐 아니라 밖에서 `selection` 을 갈아끼운 뒤에도 돌려야
        // 휠에 보이는 값과 바인딩 값이 어긋난 채로 남지 않는다.
        .onChange(of: selection, initial: true) { _, _ in normalizeSelection() }
    }

    // MARK: - Binding

    private var periodBinding: Binding<DayPeriod?> {
        Binding(
            get: { period(of: range.resolved(selection)) },
            set: { newValue in
                guard let newValue else { return }
                let resolved = range.resolved(selection)
                update(period: newValue, hour: hour12(of: resolved), minute: resolved.minute ?? 0)
            }
        )
    }

    private var hourBinding: Binding<Int?> {
        Binding(
            get: { hour12(of: range.resolved(selection)) },
            set: { newValue in
                guard let newValue else { return }
                let resolved = range.resolved(selection)
                update(period: period(of: resolved), hour: newValue, minute: resolved.minute ?? 0)
            }
        )
    }

    private var minuteBinding: Binding<Int?> {
        Binding(
            get: { range.resolved(selection).minute },
            set: { newValue in
                guard let newValue else { return }
                let resolved = range.resolved(selection)
                update(period: period(of: resolved), hour: hour12(of: resolved), minute: newValue)
            }
        )
    }

    // MARK: - Value

    /// 빈 필드나 하한보다 앞선 시각을 들고 들어온 경우 밖의 값도 휠이 보여주는 값으로 맞춰준다.
    ///
    /// 이미 맞으면 아무것도 쓰지 않아 `onChange` 가 스스로를 다시 불러 되먹임하는 일이 없다.
    private func normalizeSelection() {
        let resolved = range.resolved(selection)
        guard selection.hour != resolved.hour || selection.minute != resolved.minute else {
            return
        }

        selection = resolved
    }

    private func update(period: DayPeriod, hour: Int, minute: Int) {
        var components = selection
        components.hour = (hour % 12) + (period == .pm ? 12 : 0)
        components.minute = minute
        selection = range.resolved(components)
    }

    private func period(of components: DateComponents) -> DayPeriod {
        min(max(components.hour ?? 0, 0), 23) < 12 ? .am : .pm
    }

    /// 12시간제 시각. 0시와 12시는 둘 다 `12` 로 보인다.
    private func hour12(of components: DateComponents) -> Int {
        let hour = min(max(components.hour ?? 0, 0), 23) % 12
        return hour == 0 ? 12 : hour
    }
}

// MARK: - DayPeriod

public enum DayPeriod: CaseIterable, Hashable, Sendable {
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

#if DEBUG
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
    .background(Color.bgDefault)
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
    .background(Color.bgDefault)
}
#endif
