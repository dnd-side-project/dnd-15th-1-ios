import SharedDesignSystem
import SwiftUI
import UIKit

// 숨은 입력칸 하나가 실제 입력을 받고, 칸 5 개는 그 값을 잘라 보여준다.
// 정규화는 입력칸이 먼저 하고 리듀서가 한 번 더 한다. 입력칸이 거르지 않으면
// 리듀서가 자른 값이 화면으로 되돌아가지 않아 자릿수 제한이 샌다
struct CodeInputField: View {
    @Binding var code: String
    /// UIKit 입력칸은 `@FocusState` 로 잡히지 않아 포커스를 값으로 주고받는다
    @Binding var isFocused: Bool
    let length: Int

    var body: some View {
        ZStack {
            hiddenField
            boxes
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }

    private var hiddenField: some View {
        SanitizingTextField(
            text: $code,
            placeholder: "",
            typography: .largeTitleB,
            textColor: UIColor(Color.gray900),
            keyboardType: .asciiCapable,
            autocapitalization: .allCharacters,
            isFocused: $isFocused,
            sanitize: CoupleConnectFeature.normalizedCode,
            onSubmit: { isFocused = false }
        )
        .frame(width: 1, height: 1)
        .opacity(0.01)
        .accessibilityHidden(true)
    }

    private var boxes: some View {
        HStack(spacing: 4) {
            ForEach(0..<length, id: \.self) { index in
                box(character(at: index))
            }
        }
    }

    private func box(_ character: String) -> some View {
        Text(character)
            .typography(.largeTitleB)
            .foregroundStyle(Color.gray900)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(Color.gray50)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func character(at index: Int) -> String {
        guard index < code.count else { return "" }
        let target = code.index(code.startIndex, offsetBy: index)
        return String(code[target])
    }
}

#if DEBUG
private struct CodeInputFieldPreview: View {
    @State private var code: String
    @State private var isFocused = false

    init(code: String) {
        _code = State(initialValue: code)
    }

    var body: some View {
        CodeInputField(code: $code, isFocused: $isFocused, length: 5)
            .padding(.horizontal, 20)
    }
}

#Preview("빈 값") {
    CodeInputFieldPreview(code: "")
}

#Preview("입력 중") {
    CodeInputFieldPreview(code: "AB1")
}

#Preview("모두 입력") {
    CodeInputFieldPreview(code: "AB12C")
}
#endif
