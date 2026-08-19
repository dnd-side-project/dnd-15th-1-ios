import SharedDesignSystem
import SwiftUI

// MARK: - MapBottomSheetMetric

private enum MapBottomSheetMetric {
    static let cornerRadius: CGFloat = 32
    static let grabberWidth: CGFloat = 50
    static let grabberHeight: CGFloat = 6
    static let grabberTopInset: CGFloat = 14
    static let grabberBottomInset: CGFloat = 13
    static let shadowRadius: CGFloat = 6
    static let shadowOpacity: CGFloat = 0.05
    static let shadowOffsetY: CGFloat = -4
    static let minimumDragDistance: CGFloat = 4
    static let fadeDuration: Double = 0.2

    /// `above` 아래 끝과 시트 윗면 사이
    static let gapAboveSheet: CGFloat = 16

    /// 손 뗀 뒤 단계에 붙는 움직임
    static let settle: Animation = .spring(response: 0.32, dampingFraction: 0.86)

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
/// 모달이며 높이가 내용에 맞춰 고정된다. 껍데기 값(모서리 32, 잡이 막대 50 × 6)은 맞춰뒀다.
///
/// 단계는 접힘과 펼침 둘뿐이다. 접힘은 기기 화면 전체 높이의 50%, 펼침은 `expandLimit` 이 정한다.
/// 손을 떼면 가까운 단계로 붙는다.
///
/// 시트 높이를 단계 높이로 두고 그 창 안에서 본문이 스크롤된다.
/// 접힘에서는 본문이 안 스크롤된다. 펼침에서 본문이 맨 위가 아니면 스크롤된다.
/// 잡이 막대와 헤더는 고정된다. 목록만 스크롤된다.
///
/// 잡이 막대 아래로 `header` · `content` 두 자리를 받는다. `header` 는 없어도 된다.
/// `above` 는 시트 윗면 바로 위에 얹혀 카드를 따라 움직이고, 접힘보다 위로 올라가면 사라진다.
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

    /// 열린 메뉴의 화면 좌표. 시작점이 이 안이면 시트 손짓을 시작하지 않는다
    private let openMenuFrames: [CGRect]

    /// 손짓 주인이 시트로 정해지는 순간 한 번 불린다. 열린 메뉴를 닫는 데 쓴다
    private let onDragBegan: (() -> Void)?

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

    var body: some View {
        GeometryReader { proxy in
            sheet(layout: layout(in: proxy.size.height))
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
        openMenuFrames: [CGRect] = [],
        onDragBegan: (() -> Void)? = nil,
        @ViewBuilder above: () -> Above,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self._selection = selection
        self.expandLimit = expandLimit
        self.openMenuFrames = openMenuFrames
        self.onDragBegan = onDragBegan
        self.above = above()
        self.header = header()
        self.content = content()
    }
}

extension MapBottomSheet where Above == EmptyView {

    init(
        selection: Binding<SheetDetent>,
        expandLimit: SheetExpandLimit,
        openMenuFrames: [CGRect] = [],
        onDragBegan: (() -> Void)? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            selection: selection,
            expandLimit: expandLimit,
            openMenuFrames: openMenuFrames,
            onDragBegan: onDragBegan,
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
        openMenuFrames: [CGRect] = [],
        onDragBegan: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            selection: selection,
            expandLimit: expandLimit,
            openMenuFrames: openMenuFrames,
            onDragBegan: onDragBegan,
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
        openMenuFrames: [CGRect] = [],
        onDragBegan: (() -> Void)? = nil,
        @ViewBuilder above: () -> Above,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            selection: selection,
            expandLimit: expandLimit,
            openMenuFrames: openMenuFrames,
            onDragBegan: onDragBegan,
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
            expandLimit: expandLimit
        )
    }

    /// 시트 높이가 단계를 오간다. 본문은 그 창 안에서 스크롤된다.
    ///
    /// 카드 높이는 펼침 높이로 못 박고, 오르내림은 `.offset(y:)` 하나가 맡는다.
    /// 높이를 매 프레임 바꾸면 카드 안 전체 — 헤더, 목록, 행마다의 가로 스크롤 — 가
    /// 프레임마다 레이아웃을 다시 하고 그림자 모양도 매 프레임 다시 계산된다.
    /// `.offset` 은 배치 결과를 안 바꿔 그 비용이 없다. 접힘에서는 카드 아랫부분이
    /// 담는 층 바닥 아래(화면 밖)에 내려가 있을 뿐이고, 보이는 픽셀은 이전과 같다.
    func sheet(layout: SheetLayout) -> some View {
        VStack(spacing: 0) {
            // 헤더가 드롭다운처럼 자기 밖 아래로 펼치는 걸 담을 수 있다.
            // 올려두지 않으면 뒤에 그려지는 본문이 그 펼침을 덮는다
            fixedTop
                .zIndex(1)
            scrollingContent
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
            header
        }
    }

    /// 펼침에서만 스크롤되는 본문.
    ///
    /// 접힘에서 스크롤을 열어두면 목록을 쓸 때 시트가 안 펼쳐진다.
    /// 맨 위인지는 손짓을 시트와 스크롤 중 어디로 보낼지 가르는 근거라 매번 받아둔다
    var scrollingContent: some View {
        ScrollView {
            content
                // 안쪽 가로 스크롤이 스스로 잠그는 근거다. scrollDisabled 가 거기까지 안 닿는다
                .environment(\.isSheetDragging, isDraggingSheet)
        }
        // 접힘에서 스크롤을 열어두면 목록을 쓸 때 시트가 안 펼쳐진다.
        // 시트가 손짓을 들고 있는 동안에도 잠근다. 안 잠그면 시트가 오르내릴 때 목록도 같이 스크롤된다
        .scrollDisabled(selection != .expanded || isDraggingSheet)
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
        GeometryReader { proxy in
            Color.clear
                .onGeometryChange(for: CGFloat.self) { _ in proxy.size.height } action: { height in
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
        didPlaceSheet = true
        guard animated else {
            visibleHeight = target
            return
        }
        withAnimation(MapBottomSheetMetric.settle) {
            visibleHeight = target
        }
    }

    /// `above` 는 접힘일 때만 보인다. 접힘보다 위로 끌면 사라진다
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
        dragBaseline = 0

        withAnimation(MapBottomSheetMetric.settle) {
            visibleHeight = layout.height(for: target)
            dragTranslation = 0
            selection = target
        }
    }

    /// 이번 손짓의 주인을 정한다. 판정은 `SheetLayout` 이 하고 여기는 뷰 상태만 모은다
    func decideDragOwner(_ value: DragGesture.Value) -> SheetDragOwner? {
        SheetLayout.dragOwner(
            detent: selection,
            isContentAtTop: isContentAtTop,
            translation: value.translation,
            startedInOpenMenu: openMenuFrames.contains { $0.contains(value.startLocation) }
        )
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

    @State private var selection: SheetDetent = .collapsed

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.gray200
                .ignoresSafeArea()

            Text(selection == .collapsed ? "접힘" : "펼침")
                .typography(.caption1M)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, Spacing.s32)

            MapBottomSheet(
                selection: $selection,
                expandLimit: expandLimit
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
}

// 저장한 장소 · 게시글 상세 — 펼치면 서치바를 덮고 안전영역 위 끝까지
#Preview("펼침이 안전영역 위 끝까지") {
    MapBottomSheetPreviewHost(expandLimit: .safeAreaTop, rowCount: 20)
}

// 장소 상세 · 검색 결과 · 장소 선택 — 펼치면 서치바 아래 8 에서 멈춘다
#Preview("펼침이 서치바 아래 8") {
    MapBottomSheetPreviewHost(expandLimit: .belowSearchBar, rowCount: 20)
}

// 내용이 펼침 높이보다 짧을 때. 흰 카드가 펼침 자리까지 늘어난다
#Preview("짧은 목록") {
    MapBottomSheetPreviewHost(expandLimit: .safeAreaTop, rowCount: 2)
}
#endif
