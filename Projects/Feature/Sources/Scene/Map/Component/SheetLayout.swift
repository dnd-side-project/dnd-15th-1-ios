import CoreGraphics

// MARK: - SheetDetent

/// 시트가 멈추는 단계.
///
/// 2단계 화면(장소 상세 · 게시글 상세 · 코스 상세)은 `collapsed` · `expanded` 둘만 쓴다.
/// 3단계 화면(지도 탭 · 코스 짜기)은 최소 높이를 넘겨 `minimum` 을 더 쓴다
enum SheetDetent: Hashable, Sendable {

    /// 최소. 3단계 화면에서만 쓴다. 높이는 화면이 재서 넘긴 `SheetLayout.minimumHeight` 다
    case minimum

    /// 접힘. 기기 화면 전체 높이의 `SheetLayout.collapsedRatio` 만큼 보인다.
    /// 3단계 화면에서는 중간이다
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
/// 분해 문서 `2026-08-13-map-course-ui-split.md:213-220` 의 표가 SSOT 다.
/// 표의 A 는 `followsContent`, B 는 `grabberOnly` 다.
enum SheetGestureKind: Hashable, Sendable {

    /// 펼침이 아닐 때(최소 · 접힘) 목록을 쓸면 시트가 먼저 오른다. 저장한 장소 · 장소 상세 · 게시글 상세 · 검색 결과가 쓴다
    case followsContent

    /// 펼침이 아니면(최소 · 접힘) 목록만 스크롤되고 시트는 손잡이로만 움직인다.
    /// 펼침에서는 목록 맨 위를 아래로 끌면 시트가 내려간다. 목록이 더 갈 곳이 없어서다.
    /// 코스 화면 둘이 쓴다
    case grabberOnly
}

// MARK: - SheetLayout

/// 시트가 설 자리를 내는 계산.
///
/// 뷰 상태를 안 읽어 따로 시험할 수 있다. 뷰는 두 높이를 넣고 결과만 받아 쓴다.
/// `containerHeight` 는 안전영역 위 끝에서 화면 바닥까지고, `screenHeight` 는 기기 화면 전체다.
/// 접힘은 화면 전체 기준이고 펼침은 담는 층 기준이라 둘을 다 받는다.
/// 최소는 화면이 재서 넘긴다. 안 넘기면 지금까지의 2단계 시트와 똑같이 돈다
struct SheetLayout: Equatable {

    /// 접힘에서 보이는 높이의 기본 비율. 기기 화면 전체 높이 대비다.
    /// 40~45% 안에서 실기기로 맞춘다 (2026-08-21 결정)
    static let collapsedScreenRatio: CGFloat = 0.45

    /// 안전영역 위 끝에서 화면 바닥까지
    let containerHeight: CGFloat

    /// 기기 화면 전체 높이
    let screenHeight: CGFloat

    let expandLimit: SheetExpandLimit

    /// 접힘에서 보이는 높이의 비율. 기기 화면 전체 높이 대비다. 3단계 화면에서는 중간의 비율이다
    let collapsedRatio: CGFloat

    /// 최소 단계에서 보이는 높이. 화면이 재서 넘긴다. `nil` 이면 최소가 없는 2단계 시트다
    let minimumHeight: CGFloat?

    init(
        containerHeight: CGFloat,
        screenHeight: CGFloat,
        expandLimit: SheetExpandLimit,
        collapsedRatio: CGFloat = SheetLayout.collapsedScreenRatio,
        minimumHeight: CGFloat? = nil
    ) {
        self.containerHeight = containerHeight
        self.screenHeight = screenHeight
        self.expandLimit = expandLimit
        self.collapsedRatio = collapsedRatio
        self.minimumHeight = minimumHeight
    }

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
        min(screenHeight * collapsedRatio, expandedHeight)
    }

    /// 가장 낮은 단계에서 보이는 높이. 최소가 있으면 최소, 없으면 접힘이다.
    /// 최소는 접힘을 넘지 않는다. 넘기면 단계 순서가 뒤집힌다
    var lowestHeight: CGFloat {
        guard let minimumHeight else { return collapsedHeight }
        return min(max(minimumHeight, 0), collapsedHeight)
    }

    /// 이 시트가 멈추는 단계. 낮은 것부터다
    var detents: [SheetDetent] {
        minimumHeight == nil ? [.collapsed, .expanded] : [.minimum, .collapsed, .expanded]
    }

    /// 최소가 없는 시트에서 `.minimum` 을 물으면 접힘 높이를 돌려준다
    func height(for detent: SheetDetent) -> CGFloat {
        switch detent {
        case .minimum:
            return lowestHeight
        case .collapsed:
            return collapsedHeight
        case .expanded:
            return expandedHeight
        }
    }

    /// 그 단계에서 화면 밖으로 내려가 있는 카드 높이.
    ///
    /// 카드는 늘 펼침 높이로 서고 `.offset` 으로 내려간다. 펼침이 아니면(최소 · 접힘) 이만큼이
    /// 담는 층 바닥 아래에 있어 본문 스크롤의 바닥도 거기 있다.
    /// 이 값을 본문 아래 여백으로 주지 않으면 목록 끝이 화면 밖에 갇힌다
    func hiddenHeight(for detent: SheetDetent) -> CGFloat {
        max(expandedHeight - height(for: detent), 0)
    }

    /// 시트 윗면의 담는 층 위 끝 기준 y
    func top(forVisible visibleHeight: CGFloat) -> CGFloat {
        containerHeight - visibleHeight
    }

    /// 2단계 화면은 접힘 아래로만 고무줄을 건다. 3단계 화면은 최소에서 딱 멈춘다.
    /// 최소가 탭바 바로 위라 손가락이 쉽게 지나쳐, 고무줄을 걸면 놓을 때 튕겨 돌아온다.
    /// 펼침 위로는 둘 다 딱 멈춘다
    func banded(_ raw: CGFloat) -> CGFloat {
        guard raw < lowestHeight else { return min(raw, expandedHeight) }
        guard minimumHeight == nil else { return lowestHeight }
        return lowestHeight + SheetRubberBand.offset(
            overflow: raw - lowestHeight,
            dimension: containerHeight
        )
    }

    /// 이보다 짧게 남은 이동은 속도를 안 넘긴다. 0 으로 나누는 것을 막는다
    static let settleDistanceTolerance: CGFloat = 1

    /// 손 뗀 뒤 단계에 붙는 스프링이 이어받을 초기 속도. 남은 이동 거리 대비 상대값이다.
    ///
    /// 가는 쪽으로 움직이던 중이면 양수다. 넘침 없는 스프링도 초기 속도가 크면 목표를 지나치므로 `limit` 로 자른다
    ///
    /// - Parameters:
    ///   - fingerVelocity: 손가락의 세로 속도. 아래로 가면 양수다
    ///   - start: 손 뗀 순간 보이는 높이
    ///   - target: 붙을 단계의 높이
    static func settleVelocity(
        fingerVelocity: CGFloat,
        from start: CGFloat,
        to target: CGFloat,
        limit: CGFloat
    ) -> CGFloat {
        // 손가락이 아래로 가면 보이는 높이는 준다. 남은 거리도 높이가 주는 쪽을 양수로 잰다
        let distance = start - target
        guard abs(distance) > settleDistanceTolerance else { return 0 }
        return min(max(fingerVelocity / distance, -limit), limit)
    }

    /// 손 뗀 자리에서 가까운 단계. 두 단계에서 거리가 같으면 낮은 쪽으로 본다
    func nearestDetent(to visibleHeight: CGFloat) -> SheetDetent {
        // min(by:) 는 같으면 앞의 것을 남긴다. `detents` 가 낮은 것부터라 낮은 쪽이 남는다
        detents.min { lhs, rhs in
            abs(visibleHeight - height(for: lhs)) < abs(visibleHeight - height(for: rhs))
        } ?? .collapsed
    }

    /// 세로 손짓을 시트가 받을지 본문 스크롤에 넘길지 정한다.
    ///
    /// `followsContent` 는 펼침이 아니면(최소 · 접힘) 본문이 안 스크롤되므로 시트가 늘 받는다.
    /// 펼침에서는 본문이 맨 위이고 아래로 끄는 손짓만 시트가 받는다.
    /// `grabberOnly` 는 펼침이 아니면 손잡이 밖 손짓을 안 받는다. 펼침에서는 `followsContent` 와 같다.
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
        case .followsContent:
            guard detent == .expanded else { return true }
            return isContentAtTop && translationY > 0
        case .grabberOnly:
            guard detent == .expanded else { return false }
            return isContentAtTop && translationY > 0
        }
    }

    /// 본문 스크롤을 열어둘지. `grabberOnly` 는 최소 · 접힘에서도 연다.
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
        case .followsContent:
            return detent == .expanded
        case .grabberOnly:
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
    ///   - startedInGrabber: 손짓 시작점이 손잡이 또는 잡는 칸 안이었는지. `grabberOnly` 가 시트를 움직이는 유일한 길이다
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

    /// 손잡이 줄이거나, 시트가 넘긴 제목 줄이면 펼침이 아니어도(최소 · 접힘) 시트가 움직인다
    static func isGrabStart(
        location: CGPoint,
        grabberFrame: CGRect,
        extraFrames: [CGRect]
    ) -> Bool {
        grabberFrame.contains(location) || extraFrames.contains { $0.contains(location) }
    }
}

// MARK: - 3단계 화면이 쓰는 판정

extension SheetLayout {

    /// 최소 단계에서 보이는 높이. 필터 아래 끝이 아래 가림막(탭바 · 버튼 영역) 위 끝보다 `gap` 위에 서게 한다.
    ///
    /// 시트가 보이는 높이는 담는 층 바닥에서 잰다. 그래서 가림막 높이도 담는 층 바닥에서 잰 값을 받는다.
    /// 둘 중 하나라도 아직 못 쟀으면 `nil` 이다. 그동안 시트는 2단계로 돈다
    ///
    /// - Parameters:
    ///   - filterBottomInSheet: 시트 위 끝에서 필터 줄 아래 끝까지
    ///   - gap: 필터 아래 끝과 가림막 위 끝 사이
    ///   - obstacleHeight: 담는 층 바닥에서 가림막 위 끝까지
    static func minimumHeight(
        filterBottomInSheet: CGFloat,
        gap: CGFloat,
        obstacleHeight: CGFloat
    ) -> CGFloat? {
        guard filterBottomInSheet > 0, obstacleHeight > 0 else { return nil }
        return filterBottomInSheet + gap + obstacleHeight
    }

    /// 시트 위 끝에서 필터 줄 아래 끝까지. 최소 단계 높이의 근거다.
    ///
    /// 자리(`frame.maxY`)가 아니라 크기를 더해 낸다. 카드 안 자리는 시트가 오르내리는 동안 바뀌어,
    /// 최소 높이가 프레임마다 흔들리고 최소에서 멈춘 뒤에도 소수 픽셀 사이를 오갔다.
    /// 크기는 `.offset` 이동에 영향받지 않는다. 화면 픽셀 자리로 반올림해 소수 오차도 지운다.
    /// 헤더를 아직 못 쟀으면 0 이라, 최소가 없는 채로 둔다
    ///
    /// - Parameters:
    ///   - grabberAreaHeight: 잡는 칸 높이. `MapBottomSheetMetric.grabberAreaHeight`
    ///   - headerHeightToFilter: 헤더 위 끝에서 필터 줄 아래 끝까지의 높이
    ///   - displayScale: 화면 배율. 3배율이면 1pt 가 3픽셀이다
    static func filterBottomInSheet(
        grabberAreaHeight: CGFloat,
        headerHeightToFilter: CGFloat,
        displayScale: CGFloat
    ) -> CGFloat {
        guard headerHeightToFilter > 0 else { return 0 }
        return pixelAligned(grabberAreaHeight + headerHeightToFilter, displayScale: displayScale)
    }

    /// 화면 픽셀 자리로 반올림한다. 배율을 모르면(0 이하) 그대로 둔다
    static func pixelAligned(_ value: CGFloat, displayScale: CGFloat) -> CGFloat {
        guard displayScale > 0 else { return value }
        return (value * displayScale).rounded() / displayScale
    }

    /// 사용자가 지도를 손으로 움직이기 시작할 때 시트가 갈 단계.
    ///
    /// 화면에 보이는 중간 시트만 최소로 내린다. 최소 · 최대는 그대로다.
    /// 상세에 가려 안 보이는 시트는 몰래 바꾸지 않는다. 최소가 없는 시트도 그대로다
    static func detentAfterMapGesture(
        _ detent: SheetDetent,
        isSheetShown: Bool,
        hasMinimum: Bool
    ) -> SheetDetent {
        guard isSheetShown, hasMinimum, detent == .collapsed else { return detent }
        return .minimum
    }

    /// 필터 메뉴를 열 때 시트가 갈 단계.
    /// 드롭다운이 필터 아래로 펼쳐져 최소에서는 탭바 · 버튼 영역에 가린다. 그래서 중간으로 올린다
    static func detentForOpeningMenu(_ detent: SheetDetent) -> SheetDetent {
        detent == .minimum ? .collapsed : detent
    }
}
