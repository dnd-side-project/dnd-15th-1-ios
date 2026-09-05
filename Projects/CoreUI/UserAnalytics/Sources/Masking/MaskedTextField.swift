import SharedDesignSystem
import SwiftUI

/// 내용이 항상 녹화에서 가려지는 입력 칸.
///
/// 닉네임·검색어·별칭처럼 개인정보를 받는 자리는 `AppTextField` 대신 이것을 쓴다.
/// 클라리티는 입력 칸 일괄 가리기를 지원하지 않아 칸마다 붙여야 한다.
/// `AppTextField` 의 init 인자가 늘면 이 파일도 같이 고친다
public struct MaskedTextField: View {
    @Binding private var text: String
    private let placeholder: String
    private let size: AppTextField.Size
    private let style: AppTextField.Style
    private let accessory: AppTextField.Accessory
    private let errorMessage: String?
    private let submitLabel: SubmitLabel
    private let sanitize: ((String) -> String)?
    private let isFocused: Binding<Bool>?
    private let onSubmit: (() -> Void)?

    public init(
        text: Binding<String>,
        placeholder: String,
        size: AppTextField.Size = .large,
        style: AppTextField.Style = .filled,
        accessory: AppTextField.Accessory = .none,
        errorMessage: String? = nil,
        submitLabel: SubmitLabel = .done,
        sanitize: ((String) -> String)? = nil,
        isFocused: Binding<Bool>? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.size = size
        self.style = style
        self.accessory = accessory
        self.errorMessage = errorMessage
        self.submitLabel = submitLabel
        self.sanitize = sanitize
        self.isFocused = isFocused
        self.onSubmit = onSubmit
    }

    public var body: some View {
        AppTextField(
            text: $text,
            placeholder: placeholder,
            size: size,
            style: style,
            accessory: accessory,
            errorMessage: errorMessage,
            submitLabel: submitLabel,
            sanitize: sanitize,
            isFocused: isFocused,
            onSubmit: onSubmit
        )
        .analyticsMasked()
    }
}
