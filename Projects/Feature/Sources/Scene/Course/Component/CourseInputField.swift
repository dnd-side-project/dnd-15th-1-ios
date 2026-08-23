import SharedDesignSystem
import SwiftUI

// MARK: - CourseInputField Metric

private enum CourseInputFieldMetric {
    static let height: CGFloat = 48
    static let horizontalPadding: CGFloat = 20
    static let cornerRadius: CGFloat = 12
    static let iconSide: CGFloat = 24
    static let errorLeading: CGFloat = 8
    static let stackSpacing: CGFloat = 8
}

// MARK: - CourseInputField

/// 눌러서 시트를 여는 표시 전용 입력 필드.
///
/// 키보드가 뜨면 안 되는 자리에 쓴다. 값이 없으면 placeholder 를 흐리게 보인다.
///
/// ```swift
/// CourseInputField(value: "2026.08.05", placeholder: "날짜를 입력하세요", icon: .calendar) { }
/// ```
struct CourseInputField: View {
    private let value: String?
    private let placeholder: String
    private let icon: Image
    private let errorMessage: String?
    private let onTap: () -> Void

    init(
        value: String?,
        placeholder: String,
        icon: Image,
        errorMessage: String? = nil,
        onTap: @escaping () -> Void
    ) {
        self.value = value
        self.placeholder = placeholder
        self.icon = icon
        self.errorMessage = errorMessage
        self.onTap = onTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CourseInputFieldMetric.stackSpacing) {
            field

            if let errorMessage {
                Text(errorMessage)
                    .typography(.body2M)
                    .foregroundStyle(Color.statusError)
                    .padding(.leading, CourseInputFieldMetric.errorLeading)
            }
        }
    }
}

// MARK: - Layer

private extension CourseInputField {

    var field: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.s8) {
                Text(value ?? placeholder)
                    .typography(.body1M)
                    .foregroundStyle(value == nil ? Color.gray400 : Color.gray900)
                    .frame(maxWidth: .infinity, alignment: .leading)

                icon
                    .renderingMode(.template)
                    .resizable()
                    .frame(
                        width: CourseInputFieldMetric.iconSide,
                        height: CourseInputFieldMetric.iconSide
                    )
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.horizontal, CourseInputFieldMetric.horizontalPadding)
            .frame(height: CourseInputFieldMetric.height)
            .background(Color.gray50)
            .clipShape(RoundedRectangle(cornerRadius: CourseInputFieldMetric.cornerRadius))
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG

// MARK: - Preview

// b01 — 비어 있는 상태
#Preview("빈 값") {
    VStack(spacing: Spacing.s16) {
        CourseInputField(value: nil, placeholder: "날짜를 입력하세요", icon: .calendar) {}
        CourseInputField(value: nil, placeholder: "시간을 입력하세요", icon: .clock) {}
    }
    .padding(Spacing.s20)
}

// b03 — 채워진 상태
#Preview("채운 값") {
    VStack(spacing: Spacing.s16) {
        CourseInputField(value: "2026.08.05", placeholder: "날짜를 입력하세요", icon: .calendar) {}
        CourseInputField(value: "오후 1:00", placeholder: "시간을 입력하세요", icon: .clock) {}
    }
    .padding(Spacing.s20)
}

// b02 — 날짜 에러
#Preview("에러") {
    VStack(spacing: Spacing.s16) {
        CourseInputField(
            value: nil,
            placeholder: "날짜를 입력하세요",
            icon: .calendar,
            errorMessage: "날짜를 필수로 입력해주세요"
        ) {}

        CourseInputField(value: nil, placeholder: "시간을 입력하세요", icon: .clock) {}
    }
    .padding(Spacing.s20)
}

#endif
