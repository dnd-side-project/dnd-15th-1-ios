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

    func test_접힘은_기기_화면_높이의_45퍼센트다() {
        let sut = layout()
        // 담는 층 797 이 아니라 화면 844 의 45% 다
        XCTAssertEqual(sut.height(for: .collapsed), 844 * 0.45, accuracy: 0.001)
    }

    func test_손잡이_전용_시트는_접힘에서_목록을_쓸어도_안_움직인다() {
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .grabberOnly,
            detent: .collapsed,
            isContentAtTop: true,
            translationY: -50
        ))
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .grabberOnly,
            detent: .collapsed,
            isContentAtTop: false,
            translationY: 50
        ))
    }

    func test_손잡이_전용_시트도_펼침에서_맨위를_아래로_끌면_내려간다() {
        // 목록이 더 갈 곳이 없다. 그 손짓은 시트가 받는다
        XCTAssertTrue(SheetLayout.sheetTakesDrag(
            kind: .grabberOnly, detent: .expanded, isContentAtTop: true, translationY: 50))
    }

    func test_손잡이_전용_시트는_펼침에서_그_밖의_손짓을_본문에_넘긴다() {
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .grabberOnly, detent: .expanded, isContentAtTop: true, translationY: -50))
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .grabberOnly, detent: .expanded, isContentAtTop: false, translationY: 50))
    }

    func test_목록을_끌면_오르는_시트는_지금_규칙_그대로다() {
        XCTAssertTrue(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .collapsed, isContentAtTop: true, translationY: -50))
        XCTAssertTrue(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .expanded, isContentAtTop: true, translationY: 50))
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .expanded, isContentAtTop: true, translationY: -50))
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .expanded, isContentAtTop: false, translationY: 50))
    }

    func test_손잡이에서_시작하면_종류와_무관하게_시트가_가져간다() {
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .grabberOnly,
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 0, height: -40),
                startedInOpenMenu: false,
                startedInGrabber: true
            ),
            .sheet
        )
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .followsContent,
                detent: .expanded,
                isContentAtTop: false,
                translation: CGSize(width: 0, height: -40),
                startedInOpenMenu: false,
                startedInGrabber: true
            ),
            .sheet
        )
    }

    func test_손잡이_전용_시트는_접힘에서_손잡이_밖_세로_손짓을_본문에_넘긴다() {
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .grabberOnly,
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 0, height: -40),
                startedInOpenMenu: false,
                startedInGrabber: false
            ),
            .content
        )
    }

    func test_열린_메뉴가_손잡이보다_먼저다() {
        // 드롭다운이 손잡이 위로 펼쳐져도 그 안만 스크롤한다
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .grabberOnly,
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 0, height: -80),
                startedInOpenMenu: true,
                startedInGrabber: true
            ),
            .content
        )
    }

    func test_손잡이_전용_시트는_접힘에서도_본문이_스크롤된다() {
        XCTAssertTrue(SheetLayout.contentScrolls(kind: .grabberOnly, detent: .collapsed, isDraggingSheet: false))
        XCTAssertTrue(SheetLayout.contentScrolls(kind: .grabberOnly, detent: .expanded, isDraggingSheet: false))
    }

    func test_목록을_끌면_오르는_시트는_펼침에서만_본문이_스크롤된다() {
        XCTAssertFalse(SheetLayout.contentScrolls(kind: .followsContent, detent: .collapsed, isDraggingSheet: false))
        XCTAssertTrue(SheetLayout.contentScrolls(kind: .followsContent, detent: .expanded, isDraggingSheet: false))
    }

    func test_시트를_끄는_동안은_본문이_안_스크롤된다() {
        // 안 잠그면 시트가 오르내릴 때 목록도 같이 스크롤된다
        XCTAssertFalse(SheetLayout.contentScrolls(kind: .followsContent, detent: .expanded, isDraggingSheet: true))
        XCTAssertFalse(SheetLayout.contentScrolls(kind: .grabberOnly, detent: .collapsed, isDraggingSheet: true))
    }

    func test_접힘에서는_펼침과의_차이만큼_화면_밖에_있다() {
        let sut = layout()
        // 펼침 797, 접힘 844*0.45 = 379.8
        XCTAssertEqual(sut.hiddenHeight(for: .collapsed), 797 - 844 * 0.45, accuracy: 0.001)
    }

    func test_펼침에서는_화면_밖이_없다() {
        XCTAssertEqual(layout().hiddenHeight(for: .expanded), 0)
    }

    func test_접힘이_펼침과_같으면_화면_밖이_없다() {
        // 화면이 담는 층보다 훨씬 클 때. 접힘이 펼침으로 잘린다
        let sut = layout(containerHeight: 400, screenHeight: 1000, expandLimit: .belowSearchBar)
        XCTAssertEqual(sut.hiddenHeight(for: .collapsed), 0)
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
        XCTAssertTrue(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .collapsed, isContentAtTop: true, translationY: -50))
        XCTAssertTrue(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .collapsed, isContentAtTop: false, translationY: 50))
    }

    func test_펼침에서_본문이_맨위가_아니면_스크롤에_넘긴다() {
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .expanded, isContentAtTop: false, translationY: 50))
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .followsContent,
            detent: .expanded,
            isContentAtTop: false,
            translationY: -50
        ))
    }

    func test_펼침에서_맨위를_아래로_끌면_시트가_받는다() {
        XCTAssertTrue(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .expanded, isContentAtTop: true, translationY: 50))
    }

    func test_펼침에서_맨위를_위로_끌면_스크롤에_넘긴다() {
        // 이미 맨 위라 스크롤은 안 움직인다. 시트가 받으면 펼침 위로 끌려 어색하다
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .expanded, isContentAtTop: true, translationY: -50))
    }

    func test_이동량이_문턱보다_짧으면_주인을_안_정한다() {
        // 4pt 는 방향이 안 미덥다. 다음 프레임에 다시 본다
        XCTAssertNil(SheetLayout.dragOwner(
            kind: .followsContent,
            detent: .collapsed,
            isContentAtTop: true,
            translation: CGSize(width: 3, height: 4),
            startedInOpenMenu: false,
            startedInGrabber: false
        ))
    }

    func test_가로로_끌면_본문이_가져간다() {
        // 썸네일 가로 스크롤을 쓰는 손짓이다. 시트가 뺏으면 안 된다
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .followsContent,
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 60, height: 20),
                startedInOpenMenu: false,
                startedInGrabber: false
            ),
            .content
        )
    }

    func test_세로로_끌면_접힘에서는_시트가_가져간다() {
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .followsContent,
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 5, height: -40),
                startedInOpenMenu: false,
                startedInGrabber: false
            ),
            .sheet
        )
    }

    func test_펼침에서_목록이_맨위가_아니면_본문이_가져간다() {
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .followsContent,
                detent: .expanded,
                isContentAtTop: false,
                translation: CGSize(width: 0, height: 40),
                startedInOpenMenu: false,
                startedInGrabber: false
            ),
            .content
        )
    }

    func test_열린_메뉴에서_시작하면_본문이_가져간다() {
        // 드롭다운이 열려 있으면 그 안만 스크롤한다
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .followsContent,
                detent: .collapsed,
                isContentAtTop: true,
                translation: CGSize(width: 0, height: -80),
                startedInOpenMenu: true,
                startedInGrabber: false
            ),
            .content
        )
    }
}

@MainActor
final class SheetGrabStartTests: XCTestCase {
    func test_잡는칸은_손잡이_안이면_참이다() {
        let grabber = CGRect(x: 0, y: 0, width: 390, height: 33)
        XCTAssertTrue(SheetLayout.isGrabStart(
            location: CGPoint(x: 195, y: 16),
            grabberFrame: grabber,
            extraFrames: []
        ))
    }

    func test_잡는칸은_제목_줄_안이면_참이다() {
        let grabber = CGRect(x: 0, y: 0, width: 390, height: 33)
        let title = CGRect(x: 20, y: 33, width: 350, height: 24)
        XCTAssertTrue(SheetLayout.isGrabStart(
            location: CGPoint(x: 40, y: 40),
            grabberFrame: grabber,
            extraFrames: [title]
        ))
    }

    func test_잡는칸은_필터와_요약만_있으면_거짓이다() {
        let grabber = CGRect(x: 0, y: 0, width: 390, height: 33)
        let title = CGRect(x: 20, y: 33, width: 350, height: 24)
        XCTAssertFalse(SheetLayout.isGrabStart(
            location: CGPoint(x: 40, y: 70),
            grabberFrame: grabber,
            extraFrames: [title]
        ))
    }
}
