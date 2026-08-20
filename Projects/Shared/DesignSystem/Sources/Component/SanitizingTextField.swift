import SwiftUI
import UIKit

/// 받을 수 없는 입력은 애초에 받지 않는 입력칸.
///
/// 편집 중인 `TextField` 는 자기 버퍼를 들고 있어서, 바인딩이 다른 값을 돌려줘도 그 값으로 다시 그리지 않는다.
/// 그래서 "상태에서 자르고 바인딩으로 되돌린다" 는 방법은 글자 종류와 무관하게 통하지 않는다(2026-08-16 실기기 확인).
/// 그래서 값이 입력칸에 들어가기 전에 UIKit 델리게이트에서 판단해 거른다. 조합 중인 글자를 통째로 바꿔 넣으면
/// 이미 친 자모가 깨지므로, 그때는 거르기만 하고 입력칸을 손대지 않는다.
///
/// 리턴 키는 완료 고정이다. 이 입력칸을 다른 리턴 키로 쓸 일이 생기면 그때 파라미터로 연다
public struct SanitizingTextField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let typography: Typography
    let textColor: UIColor
    let keyboardType: UIKeyboardType
    let autocapitalization: UITextAutocapitalizationType
    /// 포커스를 화면 쪽에서 잡아야 할 때만 준다. 없으면 입력칸이 알아서 한다
    let isFocused: Binding<Bool>?
    let sanitize: (String) -> String
    let onSubmit: (() -> Void)?

    /// - Parameters:
    ///   - placeholder: 빈 문자열이면 문구를 그리지 않는다
    ///   - keyboardType: 기본값은 `UITextField` 기본과 같다
    ///   - autocapitalization: 기본값은 `UITextField` 기본과 같다
    public init(
        text: Binding<String>,
        placeholder: String,
        typography: Typography,
        textColor: UIColor,
        keyboardType: UIKeyboardType = .default,
        autocapitalization: UITextAutocapitalizationType = .sentences,
        isFocused: Binding<Bool>? = nil,
        sanitize: @escaping (String) -> String,
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.typography = typography
        self.textColor = textColor
        self.keyboardType = keyboardType
        self.autocapitalization = autocapitalization
        self.isFocused = isFocused
        self.sanitize = sanitize
        self.onSubmit = onSubmit
    }

    public func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.font = typography.uiFont
        field.textColor = textColor
        field.keyboardType = keyboardType
        field.autocapitalizationType = autocapitalization
        field.returnKeyType = .done
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartInsertDeleteType = .no
        field.text = text
        field.attributedPlaceholder = Self.attributedPlaceholder(placeholder, typography: typography)
        // 입력칸은 HStack 안에서 남는 가로를 차지해야 한다. 내용 길이에 맞춰 커지면 안 된다
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    public func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        // 조합 중에 값을 밀어 넣으면 치고 있던 글자가 깨진다. 조합이 끝난 뒤에만 맞춘다
        if uiView.markedTextRange == nil, uiView.text != text {
            uiView.text = text
        }
        // 빈 placeholder 는 UITextField 가 nil 로 되돌리므로 없는 것과 같게 본다
        if (uiView.attributedPlaceholder?.string ?? "") != placeholder {
            uiView.attributedPlaceholder = Self.attributedPlaceholder(placeholder, typography: typography)
        }
        syncAppearance(uiView)
        syncFocus(uiView)
    }

    /// UITextField 는 글자 길이만큼만 넓어진다. 남는 가로는 다 쓰고 세로만 글꼴을 따르게 한다
    public func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UITextField,
        context: Context
    ) -> CGSize? {
        let intrinsic = uiView.intrinsicContentSize
        guard let width = proposal.width, width.isFinite else { return intrinsic }
        return CGSize(width: width, height: intrinsic.height)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 같은 자리에서 글꼴·글자색·키보드가 바뀔 수 있다. 바뀐 값만 넣어 불필요한 갱신을 막는다
    private func syncAppearance(_ uiView: UITextField) {
        let font = typography.uiFont
        if uiView.font != font {
            uiView.font = font
        }
        if uiView.textColor != textColor {
            uiView.textColor = textColor
        }
        var didChangeInputTraits = false
        if uiView.keyboardType != keyboardType {
            uiView.keyboardType = keyboardType
            didChangeInputTraits = true
        }
        if uiView.autocapitalizationType != autocapitalization {
            uiView.autocapitalizationType = autocapitalization
            didChangeInputTraits = true
        }
        // 올라와 있는 키보드는 바뀐 설정을 저절로 반영하지 않는다
        if didChangeInputTraits, uiView.isFirstResponder {
            uiView.reloadInputViews()
        }
    }

    private func syncFocus(_ uiView: UITextField) {
        guard let isFocused else { return }
        let wantsFocus = isFocused.wrappedValue
        guard wantsFocus != uiView.isFirstResponder else { return }
        // 그리는 도중에 응답자를 바꾸면 레이아웃이 한 번 더 돌면서 경고가 난다
        DispatchQueue.main.async {
            if wantsFocus {
                uiView.becomeFirstResponder()
            } else {
                uiView.resignFirstResponder()
            }
        }
    }

    private static func attributedPlaceholder(
        _ placeholder: String,
        typography: Typography
    ) -> NSAttributedString {
        NSAttributedString(
            string: placeholder,
            attributes: [
                .font: typography.uiFont,
                .foregroundColor: UIColor(Color.gray400),
            ]
        )
    }

    public final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: SanitizingTextField

        init(_ parent: SanitizingTextField) {
            self.parent = parent
        }

        @objc
        func editingChanged(_ textField: UITextField) {
            let value = textField.text ?? ""
            guard parent.text != value else { return }
            parent.text = value
        }

        public func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            let decision = SanitizedTextEditor.decide(
                current: textField.text ?? "",
                range: range,
                replacement: string,
                isComposing: textField.markedTextRange != nil,
                sanitize: parent.sanitize
            )
            switch decision {
            case .accept:
                return true
            case .reject:
                return false
            case let .replace(text, caretOffset):
                apply(text, caretOffset: caretOffset, to: textField)
                return false
            }
        }

        public func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFocused?.wrappedValue = true
        }

        public func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFocused?.wrappedValue = false
        }

        /// 호출부가 준 `onSubmit` 은 그 안에서 포커스까지 정리한다. 없을 때만 여기서 키보드를 내린다
        public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            if let onSubmit = parent.onSubmit {
                onSubmit()
            } else {
                textField.resignFirstResponder()
            }
            return false
        }

        /// 우리가 직접 넣은 값은 `.editingChanged` 가 저절로 울리지 않아 바인딩까지 손으로 밀어준다
        private func apply(_ text: String, caretOffset: Int, to textField: UITextField) {
            textField.text = text
            if let position = textField.position(from: textField.beginningOfDocument, offset: caretOffset) {
                textField.selectedTextRange = textField.textRange(from: position, to: position)
            }
            textField.sendActions(for: .editingChanged)
        }
    }
}
