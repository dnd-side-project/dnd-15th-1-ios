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

// 위 클래스가 type_body_length 한계라 3단계 계산은 따로 둔다
@MainActor
final class SheetThreeStepLayoutTests: XCTestCase {
    /// 최소를 안 넘긴 2단계 시트. 위 클래스의 기본값과 같다
    private func layout() -> SheetLayout {
        SheetLayout(containerHeight: 797, screenHeight: 844, expandLimit: .safeAreaTop)
    }

    /// 지도 탭 최소 예시. 필터 아래 끝 82 + 간격 20 + 탭바 83 = 185
    private func threeStepLayout(
        minimumHeight: CGFloat = 185,
        collapsedRatio: CGFloat = 0.45
    ) -> SheetLayout {
        SheetLayout(
            containerHeight: 797,
            screenHeight: 844,
            expandLimit: .safeAreaTop,
            collapsedRatio: collapsedRatio,
            minimumHeight: minimumHeight
        )
    }

    func test_최소를_넘기면_세_단계가_된다() {
        let sut = threeStepLayout()
        XCTAssertEqual(sut.detents, [.minimum, .collapsed, .expanded])
        XCTAssertEqual(sut.height(for: .minimum), 185)
        XCTAssertEqual(sut.height(for: .collapsed), 844 * 0.45, accuracy: 0.001)
        XCTAssertEqual(sut.height(for: .expanded), 797)
    }

    func test_최소를_안_넘기면_두_단계_그대로다() {
        let sut = layout()
        XCTAssertEqual(sut.detents, [.collapsed, .expanded])
        XCTAssertEqual(sut.lowestHeight, sut.collapsedHeight)
    }

    func test_중간_비율을_화면마다_바꾼다() {
        let sut = threeStepLayout(collapsedRatio: 0.70)
        XCTAssertEqual(sut.height(for: .collapsed), 844 * 0.70, accuracy: 0.001)
    }

    func test_최소는_중간을_넘지_않는다() {
        // 넘기면 단계 순서가 뒤집혀 최소가 중간보다 높아진다
        let sut = threeStepLayout(minimumHeight: 500)
        XCTAssertEqual(sut.height(for: .minimum), sut.collapsedHeight)
    }

    func test_세_단계에서_가까운_단계로_붙는다() {
        let sut = threeStepLayout()
        let lowerMiddle = (sut.lowestHeight + sut.collapsedHeight) / 2
        XCTAssertEqual(sut.nearestDetent(to: lowerMiddle - 1), .minimum)
        XCTAssertEqual(sut.nearestDetent(to: lowerMiddle + 1), .collapsed)
        let upperMiddle = (sut.collapsedHeight + sut.expandedHeight) / 2
        XCTAssertEqual(sut.nearestDetent(to: upperMiddle - 1), .collapsed)
        XCTAssertEqual(sut.nearestDetent(to: upperMiddle + 1), .expanded)
    }

    func test_두_단계_사이_한가운데면_낮은_쪽으로_붙는다() {
        // 거리가 딱 떨어지게 화면 800 · 중간 50% 로 둔다. 최소 200 과 중간 400 의 한가운데가 300 이다
        let sut = SheetLayout(
            containerHeight: 760,
            screenHeight: 800,
            expandLimit: .safeAreaTop,
            collapsedRatio: 0.5,
            minimumHeight: 200
        )
        XCTAssertEqual(sut.nearestDetent(to: 300), .minimum)
    }

    func test_두_단계_시트는_최소로_안_붙는다() {
        XCTAssertEqual(layout().nearestDetent(to: 0), .collapsed)
    }

    func test_최소_아래로_끌면_최소에서_딱_멈춘다() {
        // 최소는 탭바 바로 위라 손가락이 쉽게 지나친다. 고무줄을 걸면 놓을 때 되돌아 튕긴다
        XCTAssertEqual(threeStepLayout().banded(185 - 100), 185)
    }

    func test_최소와_중간_사이는_고무줄_없이_그대로다() {
        // 2단계일 때는 접힘 아래라 고무줄이 걸리던 자리다
        XCTAssertEqual(threeStepLayout().banded(250), 250)
    }

    func test_최소에서는_펼침과의_차이만큼_화면_밖에_있다() {
        XCTAssertEqual(threeStepLayout().hiddenHeight(for: .minimum), 797 - 185)
    }

    func test_목록을_끌면_오르는_시트는_최소에서_시트가_손짓을_받는다() {
        XCTAssertTrue(SheetLayout.sheetTakesDrag(
            kind: .followsContent, detent: .minimum, isContentAtTop: true, translationY: -50))
        XCTAssertFalse(SheetLayout.contentScrolls(kind: .followsContent, detent: .minimum, isDraggingSheet: false))
    }

    func test_손잡이_전용_시트는_최소에서_목록만_스크롤되고_손잡이로_움직인다() {
        XCTAssertFalse(SheetLayout.sheetTakesDrag(
            kind: .grabberOnly, detent: .minimum, isContentAtTop: true, translationY: -50))
        XCTAssertTrue(SheetLayout.contentScrolls(kind: .grabberOnly, detent: .minimum, isDraggingSheet: false))
        XCTAssertEqual(
            SheetLayout.dragOwner(
                kind: .grabberOnly,
                detent: .minimum,
                isContentAtTop: true,
                translation: CGSize(width: 0, height: -40),
                startedInOpenMenu: false,
                startedInGrabber: true
            ),
            .sheet
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

@MainActor
final class SheetMinimumHeightTests: XCTestCase {
    func test_필터_아래_끝과_간격과_가림막_높이를_더한다() {
        // 시안 10.21 지도 탭 최소: 화면 852, 시트 윗면 625, 탭바 위 끝 727. 필터 아래 끝은 시트 위 끝에서 82
        XCTAssertEqual(
            SheetLayout.minimumHeight(filterBottomInSheet: 82, gap: 20, obstacleHeight: 852 - 727),
            852 - 625
        )
    }

    func test_필터를_아직_안_쟀으면_최소가_없다() {
        XCTAssertNil(SheetLayout.minimumHeight(filterBottomInSheet: 0, gap: 20, obstacleHeight: 83))
    }

    func test_가림막을_아직_안_쟀으면_최소가_없다() {
        XCTAssertNil(SheetLayout.minimumHeight(filterBottomInSheet: 82, gap: 20, obstacleHeight: 0))
    }

    func test_필터_아래_끝은_잡는_칸과_헤더의_필터까지_높이를_더한다() {
        // 3배율에서 픽셀 자리에 맞는 값은 그대로 나온다
        XCTAssertEqual(
            SheetLayout.filterBottomInSheet(grabberAreaHeight: 20, headerHeightToFilter: 62, displayScale: 3),
            82,
            accuracy: 0.0001
        )
    }

    func test_필터_아래_끝은_화면_픽셀_자리로_반올림한다() {
        // 20 + 63.27 = 83.27. 3배율 249.81 픽셀이 250 픽셀로 간다
        XCTAssertEqual(
            SheetLayout.filterBottomInSheet(grabberAreaHeight: 20, headerHeightToFilter: 63.27, displayScale: 3),
            250.0 / 3,
            accuracy: 0.0001
        )
    }

    func test_헤더를_아직_안_쟀으면_필터_아래_끝도_0_이라_최소가_없다() {
        let bottom = SheetLayout.filterBottomInSheet(grabberAreaHeight: 20, headerHeightToFilter: 0, displayScale: 3)

        XCTAssertEqual(bottom, 0)
        XCTAssertNil(SheetLayout.minimumHeight(filterBottomInSheet: bottom, gap: 20, obstacleHeight: 83))
    }

    func test_3배율에서_0점4픽셀_차이로_오가던_두_값은_같은_값이_된다() {
        // 시뮬레이터에서 최소에 멈춘 뒤 끝없이 오가던 두 값
        let low = SheetLayout.pixelAligned(83.2667, displayScale: 3)
        let high = SheetLayout.pixelAligned(83.4000, displayScale: 3)

        XCTAssertEqual(low, high)
        XCTAssertEqual(low, 250.0 / 3, accuracy: 0.0001)
    }

    func test_2배율에서는_반_포인트_자리로_반올림한다() {
        XCTAssertEqual(SheetLayout.pixelAligned(10.3, displayScale: 2), 10.5)
        XCTAssertEqual(SheetLayout.pixelAligned(10.2, displayScale: 2), 10)
    }

    func test_배율을_모르면_값을_그대로_둔다() {
        XCTAssertEqual(SheetLayout.pixelAligned(83.27, displayScale: 0), 83.27)
    }
}

@MainActor
final class SheetDetentRuleTests: XCTestCase {
    func test_보이는_중간_시트는_지도를_끌면_최소로_내려간다() {
        XCTAssertEqual(
            SheetLayout.detentAfterMapGesture(.collapsed, isSheetShown: true, hasMinimum: true),
            .minimum
        )
    }

    func test_최소와_최대는_지도를_끌어도_그대로다() {
        XCTAssertEqual(
            SheetLayout.detentAfterMapGesture(.minimum, isSheetShown: true, hasMinimum: true),
            .minimum
        )
        XCTAssertEqual(
            SheetLayout.detentAfterMapGesture(.expanded, isSheetShown: true, hasMinimum: true),
            .expanded
        )
    }

    func test_안_보이는_시트는_지도를_끌어도_그대로다() {
        // 상세에 가려 빠진 시트가 몰래 바뀌면 상세를 닫았을 때 단계가 달라져 있다
        XCTAssertEqual(
            SheetLayout.detentAfterMapGesture(.collapsed, isSheetShown: false, hasMinimum: true),
            .collapsed
        )
    }

    func test_최소가_없으면_지도를_끌어도_그대로다() {
        XCTAssertEqual(
            SheetLayout.detentAfterMapGesture(.collapsed, isSheetShown: true, hasMinimum: false),
            .collapsed
        )
    }

    func test_최소에서_필터를_열면_중간으로_오른다() {
        // 드롭다운이 필터 아래로 펼쳐져 최소에서는 탭바 · 버튼 영역에 가린다
        XCTAssertEqual(SheetLayout.detentForOpeningMenu(.minimum), .collapsed)
    }

    func test_중간과_최대에서_필터를_열면_그대로다() {
        XCTAssertEqual(SheetLayout.detentForOpeningMenu(.collapsed), .collapsed)
        XCTAssertEqual(SheetLayout.detentForOpeningMenu(.expanded), .expanded)
    }
}

@MainActor
final class SheetSettleVelocityTests: XCTestCase {
    func test_아래로_놓으면_남은_거리로_나눈_양수다() {
        // 400 에서 185 로 215 내려간다. 손가락이 초당 430 아래로 가면 남은 거리의 2배다
        XCTAssertEqual(
            SheetLayout.settleVelocity(fingerVelocity: 430, from: 400, to: 185, limit: 100),
            2,
            accuracy: 0.001
        )
    }

    func test_위로_놓아도_가는_쪽이면_양수다() {
        XCTAssertEqual(
            SheetLayout.settleVelocity(fingerVelocity: -430, from: 185, to: 400, limit: 100),
            2,
            accuracy: 0.001
        )
    }

    func test_가는_쪽과_반대로_놓으면_음수다() {
        XCTAssertEqual(
            SheetLayout.settleVelocity(fingerVelocity: -430, from: 400, to: 185, limit: 100),
            -2,
            accuracy: 0.001
        )
    }

    func test_남은_거리가_거의_없으면_0이다() {
        XCTAssertEqual(SheetLayout.settleVelocity(fingerVelocity: 1000, from: 185, to: 185, limit: 100), 0)
        XCTAssertEqual(SheetLayout.settleVelocity(fingerVelocity: 1000, from: 185.4, to: 185, limit: 100), 0)
    }

    func test_한도를_넘으면_한도로_자른다() {
        // 넘침 없는 스프링도 초기 속도가 너무 크면 목표를 지나친다
        XCTAssertEqual(SheetLayout.settleVelocity(fingerVelocity: 5000, from: 400, to: 185, limit: 20), 20)
        XCTAssertEqual(SheetLayout.settleVelocity(fingerVelocity: -5000, from: 400, to: 185, limit: 20), -20)
    }
}
