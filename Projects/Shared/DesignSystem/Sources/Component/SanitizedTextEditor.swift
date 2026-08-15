import Foundation

/// 입력칸이 글자를 받기 직전에 내리는 결정.
///
/// UIKit 델리게이트 안에서 판단하면 시뮬레이터를 띄워야만 확인할 수 있어서,
/// 판단만 떼어 값으로 만든다
public enum SanitizedTextEdit: Equatable {
    /// 정규화가 필요 없는 입력. 그대로 받는다
    case accept
    /// 받을 수 없는 입력. 입력칸을 손대지 않고 무시한다
    case reject
    /// 일부만 받는 입력. 입력칸을 `text` 로 바꾸고 커서를 `caretOffset` 에 둔다
    case replace(text: String, caretOffset: Int)
}

/// `UITextFieldDelegate.textField(_:shouldChangeCharactersIn:replacementString:)` 의 판단부.
public enum SanitizedTextEditor {
    /// - Parameters:
    ///   - current: 입력칸이 지금 들고 있는 값
    ///   - range: 바뀔 구간. UTF-16 기준이라 `NSString` 으로 다룬다
    ///   - replacement: 그 구간에 들어올 값
    ///   - isComposing: 한글처럼 아직 조합 중인 글자가 있는지 (`markedTextRange != nil`)
    ///   - sanitize: 통과시킬 값으로 다듬는 규칙
    public static func decide(
        current: String,
        range: NSRange,
        replacement: String,
        isComposing: Bool,
        sanitize: (String) -> String
    ) -> SanitizedTextEdit {
        let currentText = current as NSString
        guard range.location != NSNotFound,
              range.location >= 0,
              range.length >= 0,
              range.location + range.length <= currentText.length
        else { return .accept }

        let proposed = currentText.replacingCharacters(in: range, with: replacement)
        let sanitized = sanitize(proposed)
        guard sanitized != proposed else { return .accept }

        // 조합 중인 글자를 우리가 통째로 바꿔 넣으면 이미 친 자모가 사라진다.
        // 넘치는 입력을 받지 않기만 하고, 화면에 있는 글자는 그대로 둔다
        guard !isComposing else { return .reject }

        // 붙여넣기처럼 일부만 받을 수 있는 경우가 있어 결과가 그대로면 그때 무시한다
        guard sanitized != current else { return .reject }

        let insertedEnd = range.location + (replacement as NSString).length
        let head = (proposed as NSString).substring(to: insertedEnd)
        let caretOffset = min((sanitize(head) as NSString).length, (sanitized as NSString).length)
        return .replace(text: sanitized, caretOffset: caretOffset)
    }
}
