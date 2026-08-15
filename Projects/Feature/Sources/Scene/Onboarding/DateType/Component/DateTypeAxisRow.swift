import SharedDesignSystem
import SwiftUI

// 한 축의 두 선택지를 균등 분할로 놓고, 두 버튼 사이 정중앙에 VS 배지를 얹는다
struct DateTypeAxisRow<Value: Equatable>: View {
    struct Option {
        let value: Value
        let title: String
        let icon: Image
    }

    let leading: Option
    let trailing: Option
    let selection: Value?
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 8) {
            optionButton(leading)
            optionButton(trailing)
        }
        .overlay {
            versusBadge
        }
    }

    // AppButton 은 아이콘을 글자색으로 칠하는데 여기선 아이콘만 다른 색이라 라벨을 직접 만들고
    // 버튼 스타일만 AppButtonStyle 로 맞춘다. 글자·패딩·radius·배경은 AppButton 과 동일하다
    private func optionButton(_ option: Option) -> some View {
        let isSelected = selection == option.value

        return Button {
            onSelect(option.value)
        } label: {
            HStack(spacing: 4) {
                option.icon
                    .renderingMode(.template)
                    .foregroundStyle(isSelected ? Color.commonWhite : Color.gray400)

                Text(option.title)
            }
        }
        .buttonStyle(
            AppButtonStyle(
                variant: isSelected ? .primary : .outlined,
                size: .xl,
                fullWidth: true
            )
        )
    }

    private var versusBadge: some View {
        Text("VS")
            .typography(.body2SB)
            .foregroundStyle(Color.commonWhite)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(Color.textPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 29))
            .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("미선택") {
    DateTypeAxisRow(
        leading: .init(value: "indoor", title: "실내", icon: .dateTypeIndoor),
        trailing: .init(value: "outdoor", title: "실외", icon: .dateTypeOutdoor),
        selection: nil,
        onSelect: { _ in }
    )
    .padding(.horizontal, 20)
}

#Preview("왼쪽 선택") {
    DateTypeAxisRow(
        leading: .init(value: "indoor", title: "실내", icon: .dateTypeIndoor),
        trailing: .init(value: "outdoor", title: "실외", icon: .dateTypeOutdoor),
        selection: "indoor",
        onSelect: { _ in }
    )
    .padding(.horizontal, 20)
}
#endif
