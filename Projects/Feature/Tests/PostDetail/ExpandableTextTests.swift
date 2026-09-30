import Domain
@testable import Feature
import SwiftUI
import UIKit
import XCTest

@MainActor
final class ExpandableTextTests: XCTestCase {
    private let width: CGFloat = 353
    private var longText: String { PostDetailContent.fixture().caption ?? "" }
    private let shortText = "한 줄짜리 본문"

    func test_긴글_접힘_더보기_버튼이_높이를_키운다() {
        let height = measuredHeight(
            ExpandableText(text: longText, isExpanded: false, onToggle: {})
        )
        // 버튼이 없으면 3줄만 남아 56 근처, 있으면 89 근처다. 그 사이에 둬 글자 값이 흔들려도 안 깨진다
        XCTAssertGreaterThanOrEqual(height, 70)
    }

    func test_긴글_펼침이_접힘보다_높다() {
        let collapsed = measuredHeight(
            ExpandableText(text: longText, isExpanded: false, onToggle: {})
        )
        let expanded = measuredHeight(
            ExpandableText(text: longText, isExpanded: true, onToggle: {})
        )
        XCTAssertGreaterThan(expanded, collapsed)
    }

    func test_짧은글_접힘_버튼이_없다() {
        let height = measuredHeight(
            ExpandableText(text: shortText, isExpanded: false, onToggle: {})
        )
        XCTAssertLessThan(height, 70)
    }

    /// `onGeometryChange` 는 레이아웃 한 바퀴 뒤에 온다. 0.01초씩 쉬며 다시 재고,
    /// 높이가 세 번 연속 같으면 그 값을 돌려준다. 50번 안에 안정되지 않으면 실패한다.
    private func measuredHeight(_ view: some View) -> CGFloat {
        let host = UIHostingController(rootView: AnyView(view))
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: 10_000)

        var last: CGFloat = 0
        func pass() {
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            last = host.sizeThatFits(
                in: CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            ).height
        }

        var previous: CGFloat = -1
        var sameCount = 0
        for _ in 0 ..< 50 {
            pass()
            sameCount = last == previous ? sameCount + 1 : 0
            if sameCount == 2 { return last }
            previous = last
            RunLoop.current.run(until: Date().addingTimeInterval(0.01))
        }
        XCTFail("높이가 안정되지 않았다")
        return last
    }
}
