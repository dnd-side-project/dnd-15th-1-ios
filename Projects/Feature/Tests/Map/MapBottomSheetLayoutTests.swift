@testable import Feature
import XCTest

@MainActor
final class SheetExpandLimitTests: XCTestCase {
    func test_safeAreaTop_은_담는_층_위_끝이다() {
        XCTAssertEqual(SheetExpandLimit.safeAreaTop.topInset, 0)
    }

    func test_belowSearchBar_는_서치바_아래_8_이다() {
        // 서치바 바닥 48 + 간격 8
        XCTAssertEqual(SheetExpandLimit.belowSearchBar.topInset, 56)
    }
}

@MainActor
final class SheetLayoutTests: XCTestCase {
    /// 아이폰 14 기준. 화면 844, 안전영역 위 47 을 뺀 담는 층 797
    private func layout(
        containerHeight: CGFloat = 797,
        screenHeight: CGFloat = 844,
        expandLimit: SheetExpandLimit = .safeAreaTop
    ) -> SheetLayout {
        SheetLayout(
            containerHeight: containerHeight,
            screenHeight: screenHeight,
            expandLimit: expandLimit
        )
    }

    func test_펼침은_안전영역_위_끝까지_오른다() {
        let sut = layout()
        XCTAssertEqual(sut.height(for: .expanded), 797)
        XCTAssertEqual(sut.top(forVisible: sut.height(for: .expanded)), 0)
    }

    func test_펼침은_서치바_아래_8_에서_멈춘다() {
        let sut = layout(expandLimit: .belowSearchBar)
        XCTAssertEqual(sut.height(for: .expanded), 741)
        XCTAssertEqual(sut.top(forVisible: sut.height(for: .expanded)), 56)
    }

    func test_접힘은_기기_화면_높이의_절반이다() {
        let sut = layout()
        // 담는 층 797 이 아니라 화면 844 의 절반이다
        XCTAssertEqual(sut.height(for: .collapsed), 422)
    }

    func test_접힘이_펼침을_넘지_않는다() {
        // 화면이 담는 층보다 훨씬 클 때. 접힘이 펼침 위로 가면 시트가 뒤집힌다
        let sut = layout(containerHeight: 400, screenHeight: 1000, expandLimit: .belowSearchBar)
        XCTAssertEqual(sut.height(for: .expanded), 344)
        XCTAssertEqual(sut.height(for: .collapsed), 344)
    }

    func test_접힘_아래로_끌면_고무줄이_걸린다() {
        let sut = layout()
        let pulled = sut.banded(sut.collapsedHeight - 100)
        // 끈 만큼 다 안 내려가고, 접힘보다는 아래에 있다
        XCTAssertGreaterThan(pulled, sut.collapsedHeight - 100)
        XCTAssertLessThan(pulled, sut.collapsedHeight)
    }

    func test_펼침_위로_끌면_딱_멈춘다() {
        let sut = layout()
        XCTAssertEqual(sut.banded(sut.expandedHeight + 100), sut.expandedHeight)
    }

    func test_경계_안은_그대로_둔다() {
        let sut = layout()
        let middle = (sut.collapsedHeight + sut.expandedHeight) / 2
        XCTAssertEqual(sut.banded(middle), middle)
    }

    func test_가까운_단계로_붙는다() {
        let sut = layout()
        let middle = (sut.collapsedHeight + sut.expandedHeight) / 2
        XCTAssertEqual(sut.nearestDetent(to: middle - 1), .collapsed)
        XCTAssertEqual(sut.nearestDetent(to: middle + 1), .expanded)
    }

    func test_높이가_안_들어오면_자리를_안_정한다() {
        XCTAssertFalse(layout(containerHeight: 0).isResolved)
        XCTAssertFalse(layout(screenHeight: 0).isResolved)
        XCTAssertTrue(layout().isResolved)
    }

    func test_접힘에서는_시트가_손짓을_받는다() {
        // 접힘에서는 본문이 안 스크롤된다. 목록을 끌면 시트가 펼쳐진다
        XCTAssertTrue(SheetLayout.sheetTakesDrag(detent: .collapsed, isContentAtTop: true, translationY: -50))
        XCTAssertTrue(SheetLayout.sheetTakesDrag(detent: .collapsed, isContentAtTop: false, translationY: 50))
    }

    func test_펼침에서_본문이_맨위가_아니면_스크롤에_넘긴다() {
        XCTAssertFalse(SheetLayout.sheetTakesDrag(detent: .expanded, isContentAtTop: false, translationY: 50))
        XCTAssertFalse(SheetLayout.sheetTakesDrag(detent: .expanded, isContentAtTop: false, translationY: -50))
    }

    func test_펼침에서_맨위를_아래로_끌면_시트가_받는다() {
        XCTAssertTrue(SheetLayout.sheetTakesDrag(detent: .expanded, isContentAtTop: true, translationY: 50))
    }

    func test_펼침에서_맨위를_위로_끌면_스크롤에_넘긴다() {
        // 이미 맨 위라 스크롤은 안 움직인다. 시트가 받으면 펼침 위로 끌려 어색하다
        XCTAssertFalse(SheetLayout.sheetTakesDrag(detent: .expanded, isContentAtTop: true, translationY: -50))
    }

    func test_이동량이_문턱보다_짧으면_주인을_안_정한다() {
        // 4pt 는 방향이 안 미덥다. 다음 프레임에 다시 본다
        XCTAssertNil(SheetLayout.dragOwner(
            detent: .collapsed,
            isContentAtTop: true,
            translation: CGSize(width: 3, height: 4),
            startedInOpenMenu: false
        ))
    }

    func test_가로로_끌면_본문이_가져간다() {
        // 썸네일 가로 스크롤을 쓰는 손짓이다. 시트가 뺏으면 안 된다
        XCTAssertEqual(
            SheetLayout.dragOwner(
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 60, height: 20),
                startedInOpenMenu: false
            ),
            .content
        )
    }

    func test_세로로_끌면_접힘에서는_시트가_가져간다() {
        XCTAssertEqual(
            SheetLayout.dragOwner(
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 5, height: -40),
                startedInOpenMenu: false
            ),
            .sheet
        )
    }

    func test_펼침에서_목록이_맨위가_아니면_본문이_가져간다() {
        XCTAssertEqual(
            SheetLayout.dragOwner(
                detent: .expanded,
                isContentAtTop: false,
                translation: CGSize(width: 0, height: 40),
                startedInOpenMenu: false
            ),
            .content
        )
    }

    func test_열린_메뉴에서_시작하면_본문이_가져간다() {
        // 드롭다운이 열려 있으면 그 안만 스크롤한다
        XCTAssertEqual(
            SheetLayout.dragOwner(
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 0, height: -80),
                startedInOpenMenu: true
            ),
            .content
        )
    }
}
