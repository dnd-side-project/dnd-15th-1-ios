import Foundation
import SharedDesignSystem

/// 입력칸이 글자를 받기 직전에 내리는 판단을 부른다. 글자를 거르는 규칙은 부르는 쪽이 넘긴다
func decideTextInput(
    current: String,
    range: NSRange,
    replacement: String,
    isComposing: Bool = false,
    sanitize: (String) -> String
) -> SanitizedTextEdit {
    SanitizedTextEditor.decide(
        current: current,
        range: range,
        replacement: replacement,
        isComposing: isComposing,
        sanitize: sanitize
    )
}

/// 글의 맨 끝에 커서가 놓인 구간. UTF-16 길이로 센다
func endOfText(_ text: String) -> NSRange {
    NSRange(location: (text as NSString).length, length: 0)
}
