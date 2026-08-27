@testable import Feature
import Foundation
import SharedDesignSystem
import XCTest

/// 초대 코드 입력칸이 글자를 받기 직전에 내리는 판단.
///
/// 리듀서는 이미 값을 자르지만, 자른 값이 이전과 같으면 상태가 안 바뀌어 입력칸까지 되돌아가지 않는다.
/// 그래서 입력칸 쪽 판단도 따로 검증한다
final class CoupleCodeTextInputTests: XCTestCase {
    private func decide(
        current: String,
        range: NSRange,
        replacement: String,
        isComposing: Bool = false
    ) -> SanitizedTextEdit {
        SanitizedTextEditor.decide(
            current: current,
            range: range,
            replacement: replacement,
            isComposing: isComposing,
            sanitize: CoupleConnectFeature.normalizedCode
        )
    }

    private func end(of text: String) -> NSRange {
        NSRange(location: (text as NSString).length, length: 0)
    }

    // MARK: - 길이

    func test_다섯자까지는_그대로_받는다() {
        let edit = decide(current: "AB12", range: end(of: "AB12"), replacement: "C")

        XCTAssertEqual(edit, .accept)
    }

    func test_여섯번째_글자는_받지_않는다() {
        let current = "AB12C"

        let edit = decide(current: current, range: end(of: current), replacement: "D")

        XCTAssertEqual(edit, .reject)
    }

    func test_지우는_입력은_언제나_받는다() {
        let edit = decide(current: "AB12C", range: NSRange(location: 4, length: 1), replacement: "")

        XCTAssertEqual(edit, .accept)
    }

    /// 다 찬 상태에서 가운데를 골라 덮어쓰는 건 자릿수를 늘리지 않는다
    func test_다_찬_상태에서_한_글자를_덮어쓰면_받는다() {
        let edit = decide(current: "AB12C", range: NSRange(location: 2, length: 1), replacement: "9")

        XCTAssertEqual(edit, .accept)
    }

    // MARK: - 대문자

    func test_소문자는_대문자로_바뀌어_들어간다() {
        let edit = decide(current: "AB", range: end(of: "AB"), replacement: "c")

        XCTAssertEqual(edit, .replace(text: "ABC", caretOffset: 3))
    }

    func test_앞쪽에_소문자를_넣으면_커서가_그_글자_뒤에_선다() {
        let edit = decide(current: "AB1", range: NSRange(location: 0, length: 0), replacement: "x")

        XCTAssertEqual(edit, .replace(text: "XAB1", caretOffset: 1))
    }

    // MARK: - 글자 종류

    func test_한글은_받지_않는다() {
        let edit = decide(current: "AB", range: end(of: "AB"), replacement: "가")

        XCTAssertEqual(edit, .reject)
    }

    func test_기호와_공백은_받지_않는다() {
        XCTAssertEqual(decide(current: "AB", range: end(of: "AB"), replacement: "-"), .reject)
        XCTAssertEqual(decide(current: "AB", range: end(of: "AB"), replacement: " "), .reject)
    }

    // MARK: - 붙여넣기

    func test_긴_붙여넣기는_다섯자로_잘려_들어간다() {
        let edit = decide(
            current: "",
            range: NSRange(location: 0, length: 0),
            replacement: "ab-12 c d3"
        )

        XCTAssertEqual(edit, .replace(text: "AB12C", caretOffset: 5))
    }

    func test_이미_다섯자면_붙여넣기를_받지_않는다() {
        let current = "AB12C"

        let edit = decide(current: current, range: end(of: current), replacement: "DEF")

        XCTAssertEqual(edit, .reject)
    }

    // MARK: - 방어

    func test_범위가_어긋나면_판단하지_않는다() {
        let edit = decide(current: "AB", range: NSRange(location: 5, length: 3), replacement: "C")

        XCTAssertEqual(edit, .accept)
    }
}
