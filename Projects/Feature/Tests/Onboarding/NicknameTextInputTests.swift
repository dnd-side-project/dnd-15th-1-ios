@testable import Feature
import Foundation
import XCTest

/// 닉네임 입력칸이 글자를 받기 직전에 내리는 판단.
///
/// 리듀서는 이미 값을 자르지만, 그 결과가 입력칸까지 되돌아가지 않는 경로가 있다.
/// 그래서 입력칸 쪽 판단도 따로 검증한다
final class NicknameTextInputTests: XCTestCase {
    // MARK: - 길이

    func test_일곱번째_글자까지는_그대로_받는다() {
        let edit = decideTextInput(
            current: "가나다라마바",
            range: endOfText("가나다라마바"),
            replacement: "사",
            sanitize: NicknameFeature.sanitizedNickname
        )

        XCTAssertEqual(edit, .accept)
    }

    func test_여덟번째_글자는_받지_않는다() {
        let current = "가나다라마바사"

        let edit = decideTextInput(
            current: current,
            range: endOfText(current),
            replacement: "아",
            sanitize: NicknameFeature.sanitizedNickname
        )

        XCTAssertEqual(edit, .reject)
    }

    // MARK: - 한글 조합

    /// 조합 중에 값을 바꿔 넣으면 이미 친 자모가 사라진다. 받지 않기만 해야 한다
    func test_조합중_여덟자가_되면_입력칸을_손대지_않고_거른다() {
        let edit = decideTextInput(
            current: "가나다라마바상",
            range: NSRange(location: 6, length: 1),
            replacement: "사아",
            isComposing: true,
            sanitize: NicknameFeature.sanitizedNickname
        )

        XCTAssertEqual(edit, .reject)
    }

    /// 두벌식으로 "가나다라마바사아" 를 이어 칠 때 앞 일곱 자가 한 번도 흐트러지지 않아야 한다.
    ///
    /// 자음은 앞 글자의 받침으로 먼저 붙고, 모음이 오면 그 받침이 떨어져 다음 글자가 된다.
    /// 그래서 조합 중인 한 글자 자리에 두 글자가 들어오는 순간이 여덟 자가 되는 지점이다
    func test_조합_중간값이_이어져도_앞글자가_깨지지_않는다() {
        var field = ""
        // (조합 중이라 바뀔 글자 수, 그 자리에 들어올 값)
        let strokes: [(Int, String)] = [
            (0, "ㄱ"), (1, "가"), (1, "간"), (1, "가나"),
            (1, "낟"), (1, "나다"), (1, "달"), (1, "다라"),
            (1, "람"), (1, "라마"), (1, "맙"), (1, "마바"),
            (1, "밧"), (1, "바사"), (1, "상"),
            // 여기서 받침이 떨어져 여덟 자가 된다
            (1, "사아"),
        ]

        for (markedLength, replacement) in strokes {
            let location = (field as NSString).length - markedLength
            let range = NSRange(location: location, length: markedLength)
            let edit = decideTextInput(
                current: field,
                range: range,
                replacement: replacement,
                isComposing: markedLength > 0,
                sanitize: NicknameFeature.sanitizedNickname
            )
            guard edit == .accept else { continue }
            field = (field as NSString).replacingCharacters(in: range, with: replacement)
        }

        // 마지막 한 번만 거부되고, 그 직전까지 친 글자는 그대로 남는다
        XCTAssertEqual(field, "가나다라마바상")
        XCTAssertEqual(field.count, NicknameFeature.maxInputLength)
    }

    // MARK: - 공백

    func test_공백은_받지_않는다() {
        let edit = decideTextInput(
            current: "둘픽",
            range: endOfText("둘픽"),
            replacement: " ",
            sanitize: NicknameFeature.sanitizedNickname
        )

        XCTAssertEqual(edit, .reject)
    }

    func test_공백섞인_붙여넣기는_공백만_빼고_받는다() {
        let edit = decideTextInput(
            current: "",
            range: NSRange(location: 0, length: 0),
            replacement: " 둘 픽\n",
            sanitize: NicknameFeature.sanitizedNickname
        )

        XCTAssertEqual(edit, .replace(text: "둘픽", caretOffset: 2))
    }

    // MARK: - 붙여넣기

    func test_긴문자열_붙여넣기는_일곱자로_잘려_들어간다() {
        let edit = decideTextInput(
            current: "",
            range: NSRange(location: 0, length: 0),
            replacement: "가나다라마바사아자차카타파하",
            sanitize: NicknameFeature.sanitizedNickname
        )

        XCTAssertEqual(edit, .replace(text: "가나다라마바사", caretOffset: 7))
    }

    func test_앞쪽에_붙여넣으면_커서가_붙여넣은_끝에_선다() {
        let edit = decideTextInput(
            current: "가나다라마",
            range: NSRange(location: 0, length: 0),
            replacement: "AB1",
            sanitize: NicknameFeature.sanitizedNickname
        )

        XCTAssertEqual(edit, .replace(text: "AB1가나다라", caretOffset: 3))
    }
}
