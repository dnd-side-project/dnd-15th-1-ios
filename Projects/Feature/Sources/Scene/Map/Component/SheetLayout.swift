import CoreGraphics

// MARK: - SheetDetent

/// 시트가 멈추는 단계. 둘뿐이다.
enum SheetDetent: Hashable, Sendable {

    /// 접힘. 기기 화면 전체 높이의 50% 가 보인다
    case collapsed

    /// 펼침. 시트 윗면이 `SheetExpandLimit` 이 정한 자리까지 오른다
    case expanded
}

// MARK: - SheetExpandLimit

/// 펼쳤을 때 시트 윗면이 멈추는 자리. 담는 층 위 끝에서 잰 거리다.
enum SheetExpandLimit: Hashable, Sendable {

    /// 서치바를 덮고 안전영역 위 끝까지. 저장한 장소 · 게시글 상세가 쓴다
    case safeAreaTop

    /// 서치바 아래 8 까지. 장소 상세 · 검색 결과 · 장소 선택이 쓴다
    case belowSearchBar

    /// 안전영역 위 끝에서 서치바 바닥까지. `MapViewMetric.searchBarBottom` 과 같은 값이다
    static let searchBarBottom: CGFloat = 48

    /// 서치바 바닥과 펼친 시트 윗면 사이
    static let searchBarGap: CGFloat = 8

    /// 담는 층 위 끝에서 시트 윗면까지 남길 거리
    var topInset: CGFloat {
        switch self {
        case .safeAreaTop:
            return 0
        case .belowSearchBar:
            return Self.searchBarBottom + Self.searchBarGap
        }
    }
}

// MARK: - SheetDragOwner

/// 한 손짓을 누가 가져갈지.
///
/// 한 번 정하면 손을 뗄 때까지 안 바꾼다. 프레임마다 다시 정하면
/// 가로로 시작한 손짓이 아래로 흐를 때 시트가 뺏어가, 썸네일을 쓰다 시트가 딸려온다.
enum SheetDragOwner: Hashable, Sendable {

    /// 시트가 오르내린다. 이 동안 안쪽 스크롤은 잠근다
    case sheet

    /// 안쪽 스크롤이 가져갔다. 시트는 이 손짓을 안 본다
    case content
}

// MARK: - SheetGestureKind

/// 시트가 손짓을 받는 방식. 시트마다 하나를 고른다.
///
/// 분해 문서 `2026-08-13-map-course-ui-split.md:194-200` 의 표가 SSOT 다.
enum SheetGestureKind: Hashable, Sendable {

    /// 접힘에서 목록을 쓸면 시트가 먼저 오른다. 저장한 장소 · 장소 상세 · 게시글 상세 · 검색 결과가 쓴다
    case a // swiftlint:disable:this identifier_name

    /// 접힘에서는 목록만 스크롤되고 시트는 손잡이로만 움직인다.
    /// 펼침에서는 목록 맨 위를 아래로 끌면 시트가 내려간다. 목록이 더 갈 곳이 없어서다.
    /// 코스 화면 둘이 쓴다
    case b // swiftlint:disable:this identifier_name
}

// MARK: - SheetLayout

/// 시트가 설 자리를 내는 계산.
///
/// 뷰 상태를 안 읽어 따로 시험할 수 있다. 뷰는 두 높이를 넣고 결과만 받아 쓴다.
/// `containerHeight` 는 안전영역 위 끝에서 화면 바닥까지고, `screenHeight` 는 기기 화면 전체다.
/// 접힘은 화면 전체 기준이고 펼침은 담는 층 기준이라 둘을 다 받는다.
struct SheetLayout: Equatable {

    /// 접힘에서 보이는 높이. 기기 화면 전체 높이 대비 비율이다.
    /// 40~45% 안에서 실기기로 맞춘다 (2026-08-21 결정)
    static let collapsedScreenRatio: CGFloat = 0.45

    /// 안전영역 위 끝에서 화면 바닥까지
    let containerHeight: CGFloat

    /// 기기 화면 전체 높이
    let screenHeight: CGFloat

    let expandLimit: SheetExpandLimit

    /// 두 높이가 다 들어왔는지. 서기 전에는 시트를 그리지 않는다
    var isResolved: Bool {
        containerHeight > 0 && screenHeight > 0
    }

    /// 펼쳤을 때 보이는 높이
    var expandedHeight: CGFloat {
        max(containerHeight - expandLimit.topInset, 0)
    }

    /// 접혔을 때 보이는 높이. 화면이 담는 층보다 커도 펼침을 넘지 않는다
    var collapsedHeight: CGFloat {
        min(screenHeight * Self.collapsedScreenRatio, expandedHeight)
    }

    func height(for detent: SheetDetent) -> CGFloat {
        switch detent {
        case .collapsed:
            return collapsedHeight
        case .expanded:
            return expandedHeight
        }
    }

    /// 그 단계에서 화면 밖으로 내려가 있는 카드 높이.
    ///
    /// 카드는 늘 펼침 높이로 서고 `.offset` 으로 내려간다. 접힘에서는 이만큼이
    /// 담는 층 바닥 아래에 있어 본문 스크롤의 바닥도 거기 있다.
    /// 이 값을 본문 아래 여백으로 주지 않으면 목록 끝이 화면 밖에 갇힌다
    func hiddenHeight(for detent: SheetDetent) -> CGFloat {
        max(expandedHeight - height(for: detent), 0)
    }

    /// 시트 윗면의 담는 층 위 끝 기준 y
    func top(forVisible visibleHeight: CGFloat) -> CGFloat {
        containerHeight - visibleHeight
    }

    /// 접힘 아래로만 고무줄을 건다. 펼침 위로는 딱 멈춘다.
    ///
    /// 두 쪽을 다르게 두는 것이 이 시트의 확정 사항이다.
    /// 아래는 놓으면 돌아오는 자리가 있어 저항이 뜻을 갖지만, 위는 갈 자리가 없다
    func banded(_ raw: CGFloat) -> CGFloat {
        guard raw < collapsedHeight else { return min(raw, expandedHeight) }
        return collapsedHeight + SheetRubberBand.offset(
            overflow: raw - collapsedHeight,
            dimension: containerHeight
        )
    }

    /// 손 뗀 자리에서 가까운 단계. 같으면 접힘으로 본다
    func nearestDetent(to visibleHeight: CGFloat) -> SheetDetent {
        let toCollapsed = abs(visibleHeight - collapsedHeight)
        let toExpanded = abs(visibleHeight - expandedHeight)
        return toCollapsed <= toExpanded ? .collapsed : .expanded
    }

    /// 세로 손짓을 시트가 받을지 본문 스크롤에 넘길지 정한다.
    ///
    /// 종류 A 는 접힘에서 본문이 안 스크롤되므로 시트가 늘 받는다.
    /// 펼침에서는 본문이 맨 위이고 아래로 끄는 손짓만 시트가 받는다.
    /// 종류 B 는 접힘에서 손잡이 밖 손짓을 안 받는다. 펼침에서는 종류 A 와 같다.
    /// 손잡이 판정은 `dragOwner` 가 먼저 한다.
    ///
    /// - Parameter translationY: 아래로 끌면 양수다
    static func sheetTakesDrag(
        kind: SheetGestureKind,
        detent: SheetDetent,
        isContentAtTop: Bool,
        translationY: CGFloat
    ) -> Bool {
        switch kind {
        case .a:
            guard detent == .expanded else { return true }
            return isContentAtTop && translationY > 0
        case .b:
            guard detent == .expanded else { return false }
            return isContentAtTop && translationY > 0
        }
    }

    /// 본문 스크롤을 열어둘지. 종류 B 는 접힘에서도 연다.
    ///
    /// 시트가 손짓을 들고 있는 동안에는 종류와 무관하게 잠근다.
    /// 안 잠그면 시트가 오르내릴 때 목록도 같이 스크롤된다
    static func contentScrolls(
        kind: SheetGestureKind,
        detent: SheetDetent,
        isDraggingSheet: Bool
    ) -> Bool {
        guard !isDraggingSheet else { return false }
        switch kind {
        case .a:
            return detent == .expanded
        case .b:
            return true
        }
    }

    /// 시트 손짓으로 인정하는 세로 우세 비율. 가로 스크롤을 쓸다 시트가 딸려오는 걸 막는다
    static let verticalDominance: CGFloat = 1.5

    /// 주인을 정하는 데 필요한 최소 이동량. 이보다 짧으면 방향이 안 미덥다
    static let ownerDecisionDistance: CGFloat = 10

    /// 이번 손짓의 주인을 정한다. 아직 방향이 안 미더우면 `nil` 을 내 다음 프레임에 다시 보게 한다.
    ///
    /// - Parameters:
    ///   - translation: 손짓의 누적 이동량. 아래로 끌면 `height` 가 양수다
    ///   - startedInOpenMenu: 손짓 시작점이 열린 드롭다운 안이었는지
    ///   - startedInGrabber: 손짓 시작점이 손잡이 안이었는지. 종류 B 가 시트를 움직이는 유일한 길이다
    static func dragOwner( // swiftlint:disable:this function_parameter_count
        kind: SheetGestureKind,
        detent: SheetDetent,
        isContentAtTop: Bool,
        translation: CGSize,
        startedInOpenMenu: Bool,
        startedInGrabber: Bool
    ) -> SheetDragOwner? {
        // 드롭다운이 열려 있으면 그 안만 스크롤한다. 손잡이보다 이쪽이 먼저다
        if startedInOpenMenu {
            return .content
        }

        // 손잡이는 스크롤할 내용이 없다. 종류와 무관하게 시트가 가져간다
        if startedInGrabber {
            return .sheet
        }

        let vertical = abs(translation.height)
        let horizontal = abs(translation.width)
        guard max(vertical, horizontal) >= ownerDecisionDistance else {
            return nil
        }

        // 세로가 가로보다 확실히 클 때만. 썸네일 가로 스크롤에 시트가 딸려오는 걸 막는다
        guard vertical > horizontal * verticalDominance else {
            return .content
        }

        return sheetTakesDrag(
            kind: kind,
            detent: detent,
            isContentAtTop: isContentAtTop,
            translationY: translation.height
        ) ? .sheet : .content
    }
}
