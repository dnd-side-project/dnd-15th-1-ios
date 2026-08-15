import SharedDesignSystem
import SwiftUI

// MARK: - DateWheelPicker

/// 연 / 월 / 일 3열 휠 피커. 시안: `c09`
///
/// OS 휠(`.pickerStyle(.wheel)`)이 아니라 평평한 스크롤 목록이다.
/// 선택 바는 세 열을 가로지르는 사각 하나이고 열 뒤층에 깔린다.
/// 단위 `월` · `일` 은 휠 항목이 아니라 선택 바 위에 고정된 별도 층이라 늘 보인다.
///
/// 딤 · 하단 시트 껍데기 · `확인` 버튼은 감싸는 쪽이 만든다. 여기는 휠 영역(높이 264)까지다.
/// `selection` 에는 `year` · `month` · `day` 만 쓴다. 나머지 필드는 받은 그대로 둔다.
public struct DateWheelPicker: View {

    /// 열 3개(48×3) + 열 사이 간격(72×2) + 오른쪽 안쪽 여백 12.
    private static let trailingInset: CGFloat = Spacing.s12

    /// 열 가운데에서 단위 상자 가운데까지. 시안 기준 연/월/일 열 190.5 → `월` 218, 310.5 → `일` 338.
    private static let unitCenterOffset: CGFloat = 27.5

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.autoupdatingCurrent
        return calendar
    }()

    @Binding private var selection: DateComponents
    private let yearRange: ClosedRange<Int>

    public init(selection: Binding<DateComponents>, yearRange: ClosedRange<Int>) {
        self._selection = selection
        self.yearRange = yearRange
    }

    public var body: some View {
        ZStack {
            WheelSelectionBar()
            columns
            unitOverlay
        }
        .frame(maxWidth: .infinity)
        .frame(height: WheelMetrics.areaHeight)
        // 첫 표시(`initial`)뿐 아니라 밖에서 `selection` 을 갈아끼운 뒤에도 돌려야
        // 휠에 보이는 값과 바인딩 값이 어긋난 채로 남지 않는다.
        .onChange(of: selection, initial: true) { _, _ in normalizeSelection() }
    }

    // MARK: Layer

    private var columns: some View {
        HStack(spacing: WheelMetrics.columnSpacing) {
            WheelColumn(items: Array(yearRange), selection: yearBinding) { String($0) }
            WheelColumn(items: Array(1...12), selection: monthBinding, title: Self.twoDigits)
            WheelColumn(items: Array(1...dayCount), selection: dayBinding, title: Self.twoDigits)
        }
        .padding(.trailing, Self.trailingInset)
    }

    /// 열과 같은 가로 배치를 한 번 더 깔아 단위를 각 열 가운데 기준으로 세운다. 숫자는 단위 때문에 밀리지 않는다.
    private var unitOverlay: some View {
        HStack(spacing: WheelMetrics.columnSpacing) {
            unitSlot(nil)
            unitSlot("월")
            unitSlot("일")
        }
        .padding(.trailing, Self.trailingInset)
    }

    private func unitSlot(_ unit: String?) -> some View {
        Color.clear
            .frame(width: WheelMetrics.columnWidth, height: WheelMetrics.rowHeight)
            .overlay {
                if let unit {
                    Text(unit)
                        .typography(.body1M)
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                        .offset(x: Self.unitCenterOffset)
                }
            }
    }

    // MARK: Binding

    private var yearBinding: Binding<Int?> {
        Binding(
            get: { resolvedYear },
            set: { newValue in
                guard let newValue else { return }
                update(year: newValue, month: resolvedMonth, day: resolvedDay)
            }
        )
    }

    private var monthBinding: Binding<Int?> {
        Binding(
            get: { resolvedMonth },
            set: { newValue in
                guard let newValue else { return }
                update(year: resolvedYear, month: newValue, day: resolvedDay)
            }
        )
    }

    private var dayBinding: Binding<Int?> {
        Binding(
            get: { resolvedDay },
            set: { newValue in
                guard let newValue else { return }
                update(year: resolvedYear, month: resolvedMonth, day: newValue)
            }
        )
    }

    // MARK: Value

    private var resolvedYear: Int {
        min(max(selection.year ?? yearRange.lowerBound, yearRange.lowerBound), yearRange.upperBound)
    }

    private var resolvedMonth: Int {
        min(max(selection.month ?? 1, 1), 12)
    }

    /// 30일까지인 달에서 31일을 들고 있으면 그 달의 마지막 날로 내린다.
    private var resolvedDay: Int {
        let day = max(selection.day ?? 1, 1)
        return min(day, dayCount)
    }

    private var dayCount: Int {
        dayCount(year: resolvedYear, month: resolvedMonth)
    }

    /// 빈 필드나 그 달에 없는 날짜를 들고 들어온 경우 밖의 값도 휠이 보여주는 값으로 맞춰준다.
    ///
    /// 이미 맞으면 아무것도 쓰지 않아 `onChange` 가 스스로를 다시 불러 되먹임하는 일이 없다.
    private func normalizeSelection() {
        let year = resolvedYear
        let month = resolvedMonth
        let day = resolvedDay

        guard selection.year != year || selection.month != month || selection.day != day else {
            return
        }

        update(year: year, month: month, day: day)
    }

    private func update(year: Int, month: Int, day: Int) {
        var components = selection
        components.year = year
        components.month = month
        components.day = min(day, dayCount(year: year, month: month))
        selection = components
    }

    /// 그레고리력 기준 그 달의 일수. 윤년 2월은 29를 돌려준다.
    private func dayCount(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard
            let date = Self.calendar.date(from: components),
            let dayRange = Self.calendar.range(of: .day, in: .month, for: date)
        else {
            return 31
        }

        return dayRange.count
    }

    private static func twoDigits(_ value: Int) -> String {
        String(format: "%02d", value)
    }
}

// MARK: - Preview

// 시안: c09
#Preview("날짜") {
    @Previewable @State var selection = DateComponents(year: 2026, month: 8, day: 22)

    VStack(spacing: Spacing.s16) {
        DateWheelPicker(selection: $selection, yearRange: 2024...2028)

        Text("\(selection.year ?? 0)-\(selection.month ?? 0)-\(selection.day ?? 0)")
            .typography(.caption1R)
            .foregroundStyle(Color.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
}

// 윤년·월말 확인용. 1월 31일에서 월 휠을 2로 돌리면 29(2024는 윤년), 4로 돌리면 30 으로 내려간다.
// 2025 로 연 휠을 옮긴 뒤 2월로 돌리면 28 이 된다.
#Preview("윤년·월말") {
    @Previewable @State var selection = DateComponents(year: 2024, month: 1, day: 31)

    VStack(spacing: Spacing.s16) {
        DateWheelPicker(selection: $selection, yearRange: 2023...2026)

        Text("\(selection.year ?? 0)-\(selection.month ?? 0)-\(selection.day ?? 0)")
            .typography(.caption1R)
            .foregroundStyle(Color.textSecondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.white)
}
