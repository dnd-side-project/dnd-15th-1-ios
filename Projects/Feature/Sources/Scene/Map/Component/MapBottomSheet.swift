import SharedDesignSystem
import SwiftUI

// MARK: - MapBottomSheetMetric

enum MapBottomSheetMetric {
    static let cornerRadius: CGFloat = 32
    /// 잡는 칸은 위 여백 8 + 막대 4 + 아래 여백 8 = 20 이다 (시안 10.21)
    static let grabberWidth: CGFloat = 50
    static let grabberHeight: CGFloat = 4
    static let grabberTopInset: CGFloat = 8
    static let grabberBottomInset: CGFloat = 8
    /// 잡는 칸 전체 높이. 헤더는 이 바로 아래에서 시작한다
    static let grabberAreaHeight: CGFloat = grabberTopInset + grabberHeight + grabberBottomInset
    static let shadowRadius: CGFloat = 6
    static let shadowOpacity: CGFloat = 0.05
    static let shadowOffsetY: CGFloat = -4
    static let minimumDragDistance: CGFloat = 4
    static let fadeDuration: Double = 0.2

    /// `above` 아래 끝과 시트 윗면 사이
    static let gapAboveSheet: CGFloat = 16

    /// 손 뗀 뒤 단계에 붙는 움직임
    static let settle: Animation = .spring(response: 0.22, dampingFraction: 0.90)

    /// 3단계 화면에서 손 뗀 뒤 단계에 붙는 넘침 없는 스프링의 길이. 손 속도를 이어받는다
    static let threeStepDragSettleDuration: TimeInterval = 0.3

    /// 이어받을 상대 속도의 한도. 넘침 없는 스프링은 이보다 빠르게 출발하면 목표를 지나친다
    static let threeStepDragSettleVelocityLimit: CGFloat = 2 * .pi / threeStepDragSettleDuration

    /// 3단계 화면에서 코드가 단계를 바꿀 때의 움직임.
    /// 코드로 단계를 바꾸면 손 속도가 없어 `settle` 같은 짧은 스프링은 뚝 떨어져 보인다
    static let threeStepCodeSettle: Animation = .spring(response: 0.4, dampingFraction: 1.0)

    /// 스크롤을 맨 위로 보는 여유. 부동소수 오차와 튕김 잔여를 넘긴다
    static let contentTopTolerance: CGFloat = 0.5
}

// MARK: - MapBottomSheet

/// `presentationDetents` 를 쓰지 않는 자체 바텀시트.
///
/// 딤이 없고 아래층이 그대로 조작되어야 해서 `ZStack` 의 위층에 얹어 쓴다.
/// 시트 밖 영역은 배경이 없어 터치를 가로채지 않는다.
///
/// `BottomSheet.swift` 와 따로 둔다. 이름은 닮았지만 다른 물건이다.
/// `BottomSheet` 는 `.bottomSheet(isPresented:)` 수식어로, 딤을 깔고 바깥을 탭하면 닫히는
/// 모달이며 높이가 내용에 맞춰 고정된다. 껍데기 값(모서리 32, 잡는 칸 20, 잡이 막대 50 × 4)은 맞춰뒀다.
///
/// 단계는 접힘과 펼침 둘이고, 부르는 쪽이 `minimumHeight` 를 넘기면 최소가 더해져 셋이 된다.
/// 접힘은 기기 화면 전체 높이의 `collapsedRatio`(기본 45%), 펼침은 `expandLimit` 이 정한다.
/// 3단계 화면에서는 접힘이 중간이다. 손을 떼면 가까운 단계로 붙는다.
///
/// 시트 높이를 단계 높이로 두고 그 창 안에서 본문이 스크롤된다.
/// 펼침이 아니면(최소 · 접힘) 본문이 안 스크롤된다. 펼침에서 본문이 맨 위가 아니면 스크롤된다.
/// 잡이 막대와 헤더는 고정된다. 목록만 스크롤된다.
///
/// 잡이 막대 아래로 `header` · `content` 두 자리를 받는다. `header` 는 없어도 된다.
/// `above` 는 시트 윗면 바로 위에 얹혀 카드를 따라 움직이고, 접힘(중간)보다 위로 올라가면 사라진다.
///
/// ```swift
/// ZStack(alignment: .bottom) {
///     MapView()
///
///     MapBottomSheet(selection: $detent, expandLimit: .belowSearchBar) {
///         placeDetail
///     }
/// }
/// ```
struct MapBottomSheet<Above: View, Header: View, Content: View>: View {

    @Binding private var selection: SheetDetent

    private let expandLimit: SheetExpandLimit

    /// 접힘(3단계 화면의 중간)에서 보이는 높이의 비율. 기기 화면 전체 높이 대비다
    private let collapsedRatio: CGFloat

    /// 최소 단계에서 보이는 높이. `nil` 이면 최소가 없는 2단계 시트다
    private let minimumHeight: CGFloat?

    /// 열린 메뉴의 화면 좌표. 시작점이 이 안이면 시트 손짓을 시작하지 않는다
    private let openMenuFrames: [CGRect]

    /// 손잡이 외에 시트를 잡을 화면 좌표. 제목 줄이 여기 들어간다
    private let grabFrames: [CGRect]

    /// 이 시트가 손짓을 받는 방식. 분해 문서 `2026-08-13-map-course-ui-split.md:213-220` 표를 따른다
    private let gestureKind: SheetGestureKind

    /// 접힘 시트 윗면의 화면 전체(global) 좌표 y. 지도 카메라가 초점 자리를 잡는 근거다.
    /// 3단계 화면에서도 중간 윗면이다. 단계가 바뀌어도 이 값은 안 바뀐다
    private let onCollapsedTopChange: ((CGFloat) -> Void)?

    /// 손짓 주인이 시트로 정해지는 순간 한 번 불린다. 열린 메뉴를 닫는 데 쓴다
    private let onDragBegan: (() -> Void)?

    /// 본문 스크롤 위치. 부르는 쪽이 목록을 특정 행으로 옮길 때만 넘긴다
    private let scrollPosition: Binding<ScrollPosition>?

    private let above: Above
    private let header: Header
    private let content: Content

    /// 기기 화면 전체 높이. 접힘 높이의 기준이다.
    /// 담는 층은 안전영역과 탭바만큼 짧아 여기서 못 낸다. 안쪽 계측 층이 채운다
    @State private var screenHeight: CGFloat = 0

    /// 화면에 보이는 시트 높이.
    /// 민 양이 아니라 이 값을 들고 있어야 내용이 짧아져도 시트가 선 자리를 지킨다.
    @State private var visibleHeight: CGFloat = 0

    /// 본문 스크롤이 맨 위에 있는지. 손짓을 시트와 스크롤 중 어디로 보낼지 가르는 근거다
    @State private var isContentAtTop = true

    /// 자리를 한 번이라도 정했는지. 첫 프레임을 가릴지 정하는 근거다
    @State private var didPlaceSheet = false

    /// `above` 가 지금 보이는지. 그리는 쪽은 이 값만 읽는다.
    /// 페이드는 값을 바꾸는 `syncAboveVisibility(_:)` 의 `withAnimation` 이 건다
    @State private var isAboveShown = true

    /// 끄는 동안의 이동량. 손을 떼면 선 자리에 접어 넣는다.
    @State private var dragTranslation: CGFloat = 0

    /// 이번 손짓의 주인. 손을 뗄 때 `nil` 로 돌아간다.
    /// 한 번 정해지면 손짓이 끝날 때까지 안 바뀐다
    @State private var dragOwner: SheetDragOwner?

    /// 시트 드래그가 실제로 시작된 시점의 `translation.height`.
    /// 제스처는 손을 댄 지점부터 누적되므로, 이 값을 빼야 시트가 한 프레임에 튀지 않는다.
    @State private var dragBaseline: CGFloat = 0

    /// 손잡이의 화면 전체 좌표. 시작점이 이 안이면 시트가 손짓을 가져간다
    @State private var grabberFrame: CGRect = .zero

    var body: some View {
        GeometryReader { proxy in
            let resolved = layout(in: proxy.size.height)
            sheet(layout: resolved)
                .onChange(of: resolved, initial: true) { _, newLayout in
                    guard newLayout.isResolved else { return }
                    // 담는 층 기준 y 에 담는 층의 화면 좌표를 더해 화면 전체 기준으로 바꾼다
                    onCollapsedTopChange?(
                        proxy.frame(in: .global).minY
                            + newLayout.top(forVisible: newLayout.collapsedHeight)
                    )
                }
        }
        .background { screenHeightProbe }
    }
}

// MARK: - Init

// 기본값 있는 @ViewBuilder 파라미터는 제네릭 추론이 걸리지 않아 편의 이니셜라이저로 나눠 둔다.

extension MapBottomSheet {

    /// 시트 윗면 위에 `above` 를 얹는 쪽. 저장한 장소 시트가 이걸 쓴다
    init(
        selection: Binding<SheetDetent>,
        expandLimit: SheetExpandLimit,
        collapsedRatio: CGFloat = SheetLayout.collapsedScreenRatio,
        minimumHeight: CGFloat? = nil,
        openMenuFrames: [CGRect] = [],
        grabFrames: [CGRect] = [],
        onDragBegan: (() -> Void)? = nil,
        gestureKind: SheetGestureKind = .followsContent,
        onCollapsedTopChange: ((CGFloat) -> Void)? = nil,
        scrollPosition: Binding<ScrollPosition>? = nil,
        @ViewBuilder above: () -> Above,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.expandLimit = expandLimit
        self.collapsedRatio = collapsedRatio
        self.minimumHeight = minimumHeight
        self.openMenuFrames = openMenuFrames
        self.grabFrames = grabFrames
        self.onDragBegan = onDragBegan
        self.gestureKind = gestureKind
        self.onCollapsedTopChange = onCollapsedTopChange
        self.scrollPosition = scrollPosition
        self.above = above()
        self.header = header()
        self.content = content()
    }
}

extension MapBottomSheet where Above == EmptyView {

    init(
        selection: Binding<SheetDetent>,
        expandLimit: SheetExpandLimit,
        collapsedRatio: CGFloat = SheetLayout.collapsedScreenRatio,
        minimumHeight: CGFloat? = nil,
        openMenuFrames: [CGRect] = [],
        grabFrames: [CGRect] = [],
        onDragBegan: (() -> Void)? = nil,
        gestureKind: SheetGestureKind = .followsContent,
        onCollapsedTopChange: ((CGFloat) -> Void)? = nil,
        scrollPosition: Binding<ScrollPosition>? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            selection: selection,
            expandLimit: expandLimit,
            collapsedRatio: collapsedRatio,
            minimumHeight: minimumHeight,
            openMenuFrames: openMenuFrames,
            grabFrames: grabFrames,
            onDragBegan: onDragBegan,
            gestureKind: gestureKind,
            onCollapsedTopChange: onCollapsedTopChange,
            scrollPosition: scrollPosition,
            above: { EmptyView() },
            header: header,
            content: content
        )
    }
}

extension MapBottomSheet where Above == EmptyView, Header == EmptyView {

    init(
        selection: Binding<SheetDetent>,
        expandLimit: SheetExpandLimit,
        collapsedRatio: CGFloat = SheetLayout.collapsedScreenRatio,
        minimumHeight: CGFloat? = nil,
        openMenuFrames: [CGRect] = [],
        grabFrames: [CGRect] = [],
        onDragBegan: (() -> Void)? = nil,
        gestureKind: SheetGestureKind = .followsContent,
        onCollapsedTopChange: ((CGFloat) -> Void)? = nil,
        scrollPosition: Binding<ScrollPosition>? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            selection: selection,
            expandLimit: expandLimit,
            collapsedRatio: collapsedRatio,
            minimumHeight: minimumHeight,
            openMenuFrames: openMenuFrames,
            grabFrames: grabFrames,
            onDragBegan: onDragBegan,
            gestureKind: gestureKind,
            onCollapsedTopChange: onCollapsedTopChange,
            scrollPosition: scrollPosition,
            above: { EmptyView() },
            header: { EmptyView() },
            content: content
        )
    }
}

extension MapBottomSheet where Header == EmptyView {

    init(
        selection: Binding<SheetDetent>,
        expandLimit: SheetExpandLimit,
        collapsedRatio: CGFloat = SheetLayout.collapsedScreenRatio,
        minimumHeight: CGFloat? = nil,
        openMenuFrames: [CGRect] = [],
        grabFrames: [CGRect] = [],
        onDragBegan: (() -> Void)? = nil,
        gestureKind: SheetGestureKind = .followsContent,
        onCollapsedTopChange: ((CGFloat) -> Void)? = nil,
        scrollPosition: Binding<ScrollPosition>? = nil,
        @ViewBuilder above: () -> Above,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            selection: selection,
            expandLimit: expandLimit,
            collapsedRatio: collapsedRatio,
            minimumHeight: minimumHeight,
            openMenuFrames: openMenuFrames,
            grabFrames: grabFrames,
            onDragBegan: onDragBegan,
            gestureKind: gestureKind,
            onCollapsedTopChange: onCollapsedTopChange,
            scrollPosition: scrollPosition,
            above: above,
            header: { EmptyView() },
            content: content
        )
    }
}

// MARK: - Layout

private extension MapBottomSheet {

    func layout(in containerHeight: CGFloat) -> SheetLayout {
        SheetLayout(
            containerHeight: containerHeight,
            screenHeight: screenHeight,
            expandLimit: expandLimit,
            collapsedRatio: collapsedRatio,
            minimumHeight: minimumHeight
        )
    }

    /// 시트 높이가 단계를 오간다. 본문은 그 창 안에서 스크롤된다.
    ///
    /// 카드 높이는 펼침 높이로 못 박고, 오르내림은 `.offset(y:)` 하나가 맡는다.
    /// 높이를 매 프레임 바꾸면 카드 안 전체 — 헤더, 목록, 행마다의 가로 스크롤 — 가
    /// 프레임마다 레이아웃을 다시 하고 그림자 모양도 매 프레임 다시 계산된다.
    /// `.offset` 은 배치 결과를 안 바꿔 그 비용이 없다. 펼침이 아니면(최소 · 접힘) 카드 아랫부분이
    /// 담는 층 바닥 아래(화면 밖)에 내려가 있을 뿐이고, 보이는 픽셀은 이전과 같다.
    func sheet(layout: SheetLayout) -> some View {
        VStack(spacing: 0) {
            // 헤더가 드롭다운처럼 자기 밖 아래로 펼치는 걸 담을 수 있다.
            // 올려두지 않으면 뒤에 그려지는 본문이 그 펼침을 덮는다
            fixedTop
                .zIndex(1)
            scrollingContent(layout: layout)
        }
        .frame(height: layout.expandedHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(Color.bgDefault)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: MapBottomSheetMetric.cornerRadius,
                topTrailingRadius: MapBottomSheetMetric.cornerRadius
            )
        )
        .shadow(
            color: Color.commonBlack.opacity(MapBottomSheetMetric.shadowOpacity),
            radius: MapBottomSheetMetric.shadowRadius,
            y: MapBottomSheetMetric.shadowOffsetY
        )
        // 클립·그림자를 한 레이어로 굳힌 뒤 offset 이 GPU 로 옮긴다
        .compositingGroup()
        .simultaneousGesture(dragGesture(layout: layout))
        // above 는 시트에 얹어야 시트 윗면을 따라 움직인다.
        // 아래 .frame 은 담는 층 전체라, 그 뒤에 얹으면 화면 맨 위에 박힌다
        .overlay(alignment: .top) { aboveSlot }
        // 카드 바닥은 아래 .frame 이 담는 층 바닥에 맞춘다.
        // 안 보여야 할 높이만큼 아래로 밀면 카드 윗면이 shownHeight 자리에 온다.
        // above 를 얹은 뒤에 밀어야 above 도 같이 따라온다
        .offset(y: layout.expandedHeight - shownHeight(layout: layout))
        // 두 높이를 재기 전에는 단계 높이를 못 정해 시트가 엉뚱한 높이로 한 프레임 그려진다
        .opacity(didPlaceSheet ? 1 : 0)
        // 담는 층 바닥에 붙인다. 담는 층이 아래 안전영역까지 뻗어 흰 배경이 탭바 뒤로 이어진다
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .onChange(of: layout, initial: true) { _, newLayout in
            placeSheet(layout: newLayout, animated: false)
        }
        .onChange(of: selection) { _, _ in
            placeSheet(layout: layout, animated: true)
        }
        // 위 onChange 옆에 얹지 않고 따로 둔다. 저쪽이 보는 높이는 끄는 동안 매 프레임 바뀌어
        // 페이드가 프레임마다 다시 시작된다. 여기는 Bool 이라 문턱을 넘는 순간에만 불린다
        .onChange(of: isAboveVisible(layout: layout), initial: true) { _, isVisible in
            syncAboveVisibility(isVisible)
        }
    }

    /// 스크롤되지 않고 시트 위에 붙어 있는 자리
    var fixedTop: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray100)
                .frame(
                    width: MapBottomSheetMetric.grabberWidth,
                    height: MapBottomSheetMetric.grabberHeight
                )
                .frame(maxWidth: .infinity)
                .padding(.top, MapBottomSheetMetric.grabberTopInset)
                .padding(.bottom, MapBottomSheetMetric.grabberBottomInset)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    if grabberFrame != $0 {
                        grabberFrame = $0
                    }
                }
            header
        }
    }

    /// 손짓 종류에 따라 스크롤이 열리는 본문.
    ///
    /// `followsContent` 는 펼침이 아닐 때(최소 · 접힘) 스크롤을 열어두면 목록을 쓸 때 시트가 안 펼쳐진다.
    /// 맨 위인지는 손짓을 시트와 스크롤 중 어디로 보낼지 가르는 근거라 매번 받아둔다
    func scrollingContent(layout: SheetLayout) -> some View {
        ScrollView {
            content
                // 안쪽 가로 스크롤이 스스로 잠그는 근거다. scrollDisabled 가 거기까지 안 닿는다
                .environment(\.isSheetDragging, isDraggingSheet)
        }
        .scrollDisabled(
            !SheetLayout.contentScrolls(
                kind: gestureKind,
                detent: selection,
                isDraggingSheet: isDraggingSheet
            )
        )
        .contentMargins(.bottom, layout.hiddenHeight(for: selection), for: .scrollContent)
        .modifier(SheetScrollPositionModifier(position: scrollPosition))
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top
        } action: { _, offset in
            let atTop = offset <= MapBottomSheetMetric.contentTopTolerance
            if isContentAtTop != atTop {
                isContentAtTop = atTop
            }
        }
        // minHeight 를 안 주면 이 자리가 내용 높이만큼 벌어져 헤더를 시트 밖으로 밀어낸다
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
    }

    /// 여기에 `.animation` 수식어를 두지 않는다. 그 수식어는 자기 아래 가지의 애니메이션까지 가져가,
    /// 손을 뗐을 때 above 만 최종 자리로 즉시 튀고 시트는 뒤늦게 미끄러져 온다.
    /// 페이드는 `syncAboveVisibility(_:)` 가 값을 바꿀 때 감싸서 건다
    var aboveSlot: some View {
        above
            .fixedSize(horizontal: false, vertical: true)
            .opacity(isAboveShown ? 1 : 0)
            .alignmentGuide(.top) { $0[.bottom] + MapBottomSheetMetric.gapAboveSheet }
    }

    /// 기기 화면 전체 높이를 재는 층.
    /// 담는 층은 안전영역과 탭바만큼 짧아 `GeometryReader` 로는 화면 높이가 안 나온다
    var screenHeightProbe: some View {
        GeometryReader { _ in
            Color.clear
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    if screenHeight != height {
                        screenHeight = height
                    }
                }
        }
        .ignoresSafeArea()
        // Color.clear 도 탭을 받는다. 시트보다 아래층이지만 확실히 비켜둔다
        .allowsHitTesting(false)
    }
}

// MARK: - Placement

private extension MapBottomSheet {

    /// 지금 시트가 손짓을 들고 있는지
    var isDraggingSheet: Bool {
        dragOwner == .sheet
    }

    /// 지금 화면에 보이는 높이. 끄는 동안의 이동량과 접힘 아래 눌림까지 반영한다
    func shownHeight(layout: SheetLayout) -> CGFloat {
        // 위로 끌면 translation 이 음수다. 빼야 보이는 높이가 커진다
        layout.banded(visibleHeight - dragTranslation)
    }

    /// 두 높이가 들어오거나 단계가 바뀌면 그 단계의 자리로 맞춘다.
    /// 끄는 동안에는 손 밑에서 시트가 튀므로 건드리지 않는다
    func placeSheet(layout: SheetLayout, animated: Bool) {
        guard layout.isResolved, !isDraggingSheet else { return }
        let target = layout.height(for: selection)
        if didPlaceSheet,
           abs(visibleHeight - target) <= MapBottomSheetMetric.contentTopTolerance {
            return
        }
        didPlaceSheet = true
        guard animated else {
            visibleHeight = target
            return
        }
        let animation = layout.minimumHeight == nil
            ? MapBottomSheetMetric.settle
            : MapBottomSheetMetric.threeStepCodeSettle
        withAnimation(animation) {
            visibleHeight = target
        }
    }

    /// `above` 는 접힘(3단계 화면의 중간) 이하일 때만 보인다. 최소에서도 보이고, 접힘보다 위로 끌면 사라진다
    func isAboveVisible(layout: SheetLayout) -> Bool {
        shownHeight(layout: layout) <= layout.collapsedHeight
    }

    /// `above` 의 보임을 페이드로 바꾼다.
    ///
    /// 애니메이션을 `aboveSlot` 의 `.animation` 수식어로 걸면 그 수식어가 자기 아래 가지의 애니메이션까지
    /// 가져가 above 만 시트와 따로 논다. 그래서 값을 바꾸는 이 자리에서만 감싼다
    func syncAboveVisibility(_ isVisible: Bool) {
        guard isAboveShown != isVisible else { return }
        withAnimation(.easeInOut(duration: MapBottomSheetMetric.fadeDuration)) {
            isAboveShown = isVisible
        }
    }
}

// MARK: - Drag

private extension MapBottomSheet {

    /// 시트 손짓. `.global` 좌표라 이동량을 그대로 민 양에 쓴다.
    func dragGesture(layout: SheetLayout) -> some Gesture {
        // 기준을 화면 전체로 잡는다. 기본값(.local)은 제스처가 붙은 시트 자기 좌표계로 재는데,
        // 시트는 이 손짓 때문에 매 프레임 움직인다. 기준이 손가락을 따라가
        // 이동 거리가 실제보다 작게 나오고, 프레임마다 기준이 달라져 값이 튄다
        DragGesture(
            minimumDistance: MapBottomSheetMetric.minimumDragDistance,
            coordinateSpace: .global
        )
            .onChanged { value in
                if dragOwner == nil {
                    guard let owner = decideDragOwner(value) else { return }
                    dragOwner = owner
                    // 정해진 시점의 누적 이동량을 기준으로 잡는다. 이후 이동은 전부 이 값과의 차다
                    dragBaseline = value.translation.height
                    if owner == .sheet {
                        onDragBegan?()
                    }
                }

                guard dragOwner == .sheet else { return }
                dragTranslation = value.translation.height - dragBaseline
            }
            .onEnded { value in
                let owner = dragOwner
                dragOwner = nil
                guard owner == .sheet else { return }
                settle(after: value, layout: layout)
            }
    }

    /// 손을 뗀 뒤 붙을 단계를 정한다.
    /// 살짝 튕긴 손짓을 놓치지 않게 속도가 섞인 예상 종점으로 잰다
    func settle(after value: DragGesture.Value, layout: SheetLayout) {
        let predictedTranslation = value.predictedEndTranslation.height - dragBaseline
        let projected = visibleHeight - predictedTranslation
        let target = layout.nearestDetent(to: projected)
        let releasedHeight = shownHeight(layout: layout)
        dragBaseline = 0

        withAnimation(settleAnimation(after: value, from: releasedHeight, to: target, layout: layout)) {
            visibleHeight = layout.height(for: target)
            dragTranslation = 0
        }
        selection = target
    }

    /// 2단계 화면은 지금 움직임 그대로다. 3단계 화면은 손 속도를 이어받는다. 정지에서 출발하면 놓는 순간 끊겨 보인다
    func settleAnimation(
        after value: DragGesture.Value,
        from releasedHeight: CGFloat,
        to target: SheetDetent,
        layout: SheetLayout
    ) -> Animation {
        guard layout.minimumHeight != nil else { return MapBottomSheetMetric.settle }
        let velocity = SheetLayout.settleVelocity(
            fingerVelocity: value.velocity.height,
            from: releasedHeight,
            to: layout.height(for: target),
            limit: MapBottomSheetMetric.threeStepDragSettleVelocityLimit
        )
        return .interpolatingSpring(
            duration: MapBottomSheetMetric.threeStepDragSettleDuration,
            bounce: 0,
            initialVelocity: velocity
        )
    }

    /// 이번 손짓의 주인을 정한다. 판정은 `SheetLayout` 이 하고 여기는 뷰 상태만 모은다
    func decideDragOwner(_ value: DragGesture.Value) -> SheetDragOwner? {
        SheetLayout.dragOwner(
            kind: gestureKind,
            detent: selection,
            isContentAtTop: isContentAtTop,
            translation: value.translation,
            startedInOpenMenu: openMenuFrames.contains { $0.contains(value.startLocation) },
            startedInGrabber: SheetLayout.isGrabStart(
                location: value.startLocation,
                grabberFrame: grabberFrame,
                extraFrames: grabFrames
            )
        )
    }
}

// MARK: - Scroll Position

/// 부르는 쪽이 스크롤 위치를 넘겼을 때만 `.scrollPosition` 을 붙인다.
/// 안 넘긴 화면은 수식어가 없어 스크롤이 지금과 같다
private struct SheetScrollPositionModifier: ViewModifier {
    let position: Binding<ScrollPosition>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let position {
            content.scrollPosition(position)
        } else {
            content
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct MapBottomSheetPreviewRow: View {
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s4) {
            Text("장소명 \(index + 1)")
                .typography(.body1SB)
                .foregroundStyle(Color.textPrimary)

            Text("경기도 안산시 모모로 145길 (뭐뭐동)")
                .typography(.caption1R)
                .foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.s20)
        .padding(.vertical, Spacing.s12)
    }
}

private struct MapBottomSheetPreviewHost: View {
    let expandLimit: SheetExpandLimit
    let rowCount: Int
    var minimumHeight: CGFloat?

    @State private var selection: SheetDetent = .collapsed

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.gray200
                .ignoresSafeArea()

            Text(detentName)
                .typography(.caption1M)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, Spacing.s32)

            MapBottomSheet(
                selection: $selection,
                expandLimit: expandLimit,
                minimumHeight: minimumHeight
            ) {
                Text("떠 있는 버튼 자리")
                    .typography(.body1M)
                    .padding(.horizontal, Spacing.s20)
            } header: {
                Text("저장한 장소")
                    .typography(.title3SB)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.s20)
                    .padding(.bottom, Spacing.s8)
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0 ..< rowCount, id: \.self) { index in
                        MapBottomSheetPreviewRow(index: index)
                        Divider()
                            .foregroundStyle(Color.borderWeak)
                    }
                }
            }
        }
    }

    private var detentName: String {
        switch selection {
        case .minimum:
            return "최소"
        case .collapsed:
            return "접힘"
        case .expanded:
            return "펼침"
        }
    }
}

// 저장한 장소 · 게시글 상세 — 펼치면 서치바를 덮고 안전영역 위 끝까지
#Preview("펼침이 안전영역 위 끝까지") {
    MapBottomSheetPreviewHost(expandLimit: .safeAreaTop, rowCount: 20)
}

// 장소 상세 · 검색 결과 · 장소 선택 — 펼치면 서치바 아래 8 에서 멈춘다
#Preview("펼침이 서치바 아래 8") {
    MapBottomSheetPreviewHost(expandLimit: .belowSearchBar, rowCount: 20)
}

// 지도 탭 · 코스 짜기 — 최소를 넘겨 세 단계가 된다. 최소 높이는 미리보기용 값이다
#Preview("세 단계") {
    MapBottomSheetPreviewHost(expandLimit: .safeAreaTop, rowCount: 20, minimumHeight: 200)
}

// 내용이 펼침 높이보다 짧을 때. 흰 카드가 펼침 자리까지 늘어난다
#Preview("짧은 목록") {
    MapBottomSheetPreviewHost(expandLimit: .safeAreaTop, rowCount: 2)
}
#endif
