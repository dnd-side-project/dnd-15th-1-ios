import SharedDesignSystem
import SwiftUI

// 숨은 TextField 하나가 실제 입력을 받고, 칸 5 개는 그 값을 잘라 보여준다.
// 정규화는 리듀서가 하므로 여기서는 값을 그대로 올려보낸다
struct CodeInputField: View {
    @Binding var code: String
    @FocusState.Binding var isFocused: Bool
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
        TextField("", text: $code)
            .focused($isFocused)
            .keyboardType(.asciiCapable)
            .textInputAutocapitalization(.characters)
            .autocorrectionDisabled()
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
    @FocusState private var isFocused: Bool

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
