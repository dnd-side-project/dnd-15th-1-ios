import Foundation
import SharedDesignSystem
import SwiftUI

// MARK: - SheetDetent

/// 바텀시트가 멈추는 단계. 담긴 컨테이너 높이 대비 비율이다.
enum SheetDetent: Hashable, Sendable {
    case fraction(CGFloat)

    var fraction: CGFloat {
        switch self {
        case let .fraction(value):
            return min(max(value, 0), 1)
        }
    }

    func height(in containerHeight: CGFloat) -> CGFloat {
        containerHeight * fraction
    }
}

// MARK: - SheetMotion

/// 시트가 손을 뗐을 때 어떻게 움직이는지.
private enum SheetMotion: Equatable {
    /// 내용 높이 그대로 그려두고 통째로 민다. 저장한 장소 시트가 이 방식이다.
    /// `minVisibleHeight` 는 가장 낮게 내렸을 때 화면에 남는 높이다.
    case free(minVisibleHeight: CGFloat)
    /// 가장 가까운 단계로 달라붙는다. 장소 상세·게시글 상세가 이 방식이다.
    case snapping([SheetDetent])
}

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

    /// 아이폰 기본 스크롤(`UIScrollView.DecelerationRate.normal`)의 감속률.
    /// 1ms 마다 남는 속도의 비율이라, 손 뗀 뒤 미끄러질 거리는 속도 × 0.499초가 된다.
    ///
    /// 감쇠 곡선 `x(t) = D(1 − e^{−kt})` 의 k 는 상수로 두지 않는다.
    /// 감쇠를 타는 갈래는 목적지가 안 잘리는 쪽뿐이라 거리가 늘 미끄러질 거리고,
    /// `|속도| ÷ |거리|` 로 내면 이 값에서 나오는 2.004 가 그대로 나온다
    static let decelerationRate: Double = 0.998

    /// 감쇠 상수를 다시 낼 수 있는 최소 이동 거리.
    /// 이보다 짧으면 `|속도| ÷ |거리|` 의 나눗셈이 터진다. 곡선이 스스로 멈추는 거리와 같은 값이다
    static let minimumDecayTravel: Double = 0.5

    /// 경계 밖에서 돌아오는 용수철의 시간. 튕김 없이 이 시간 안에 붙는다
    static let edgeReturnDuration: Double = 0.4

    /// `above` 아래 끝과 시트 윗면 사이
    static let gapAboveSheet: CGFloat = 16

    /// 시트 드래그로 인정하는 세로 우세 비율. 가로 스크롤을 쓸다 시트가 딸려오는 걸 막는다.
    static let verticalDominance: CGFloat = 1.5
}

// MARK: - MapBottomSheet

/// `presentationDetents` 를 쓰지 않는 자체 바텀시트.
///
/// 딤이 없고 아래층이 그대로 조작되어야 해서 `ZStack` 의 위층에 얹어 쓴다.
/// 시트 밖 영역은 배경이 없어 터치를 가로채지 않는다.
///
/// `BottomSheet.swift` 와 따로 둔다. 이름은 닮았지만 다른 물건이다.
/// `BottomSheet` 는 `.bottomSheet(isPresented:)` 수식어로, 딤을 깔고 바깥을 탭하면 닫히는
/// 모달이며 높이가 내용에 맞춰 고정된다. 표시 방식(overlay + 딤 + 트랜지션)을 자기가 소유해서
/// 감싸 재사용할 수 있는 구조가 아니다. 껍데기 값(모서리 32, 잡이 막대 50 × 6)은 맞춰뒀다.
///
/// 잡이 막대 아래로 헤더 · 본문 · 푸터 세 자리를 받는다. 셋 다 기본값이 있어 본문만 넘겨도 된다.
///
/// 움직임은 두 방식이다. 단계 붙기는 손을 떼면 가장 가까운 단계로 달라붙고 높이가 단계를 오간다.
/// 자유 위치는 내용 높이 그대로 그린 카드를 통째로 밀어, 시트를 올리는 것이 곧 목록을 보는 것이다.
/// 자유 위치는 `above` 자리를 하나 더 받는데, 시트 윗면 바로 위에 얹혀 카드를 따라 움직인다.
///
/// 자유 위치는 본문을 `ScrollView` 로 따로 스크롤하지 않는다.
/// SwiftUI 가 진행 중인 손짓을 `ScrollView` 로 넘겨주지 않아 시트와 목록이 한 손짓으로 안 이어지기 때문이다.
///
/// ```swift
/// ZStack(alignment: .bottom) {
///     MapView()
///
///     // 단계 붙기
///     MapBottomSheet(detents: [.fraction(0.5), .fraction(0.13)], selection: $detent) {
///         savedPlaceList
///     }
///
///     // 자유 위치
///     MapBottomSheet(minVisibleHeight: 115, initialVisibleHeight: 340, topLimit: 56) {
///         floatingButtons
///     } header: {
///         listTitle
///     } content: {
///         savedPlaceList
///     }
/// }
/// ```
struct MapBottomSheet<Above: View, Header: View, Content: View, Footer: View>: View {

    private let motion: SheetMotion
    private let selection: Binding<SheetDetent>?
    private let onHeightChange: ((CGFloat) -> Void)?

    /// 자유 위치에서 처음 화면에 남길 높이. 단계 붙기에서는 안 쓴다.
    private let initialVisibleHeight: CGFloat

    /// 시트가 올라가도 담는 층 위에 남길 여백. 내용이 짧아도 여기까지는 올라간다.
    private let topLimit: CGFloat

    /// 시트 윗면이 이 값 이하로 올라오면 `above` 가 사라진다. `nil` 이면 늘 보인다.
    private let hideAboveAtTop: CGFloat?

    /// 시트 윗면이 이 값 이하로 올라오면 `onTopCoveredChange(true)` 를 보낸다. `nil` 이면 안 보낸다.
    private let coverTopAtTop: CGFloat?
    private let onTopCoveredChange: ((Bool) -> Void)?

    /// 열린 메뉴의 화면 좌표. 시작점이 이 안이면 시트 손짓을 시작하지 않는다
    private let openMenuFrames: [CGRect]

    private let above: Above
    private let header: Header
    private let content: Content
    private let footer: Footer

    /// 자유 위치에서 화면에 보이는 시트 높이.
    /// 민 양이 아니라 이 값을 들고 있어야 내용이 짧아져도 시트가 선 자리를 지킨다.
    @State private var visibleHeight: CGFloat = 0

    /// 시트 카드가 잡은 높이. 자유 위치에서만 쓴다.
    /// 재서 알아내지 않고 `contentHeight` 에서 계산해 넣는다.
    @State private var cardHeight: CGFloat = 0

    /// 카드 안 내용(`fixedTop` + `content`)이 `.frame`·`.fixedSize` 를 만나기 전에 잡은 높이.
    /// 위에서 주는 높이에 안 눌린 값이라 카드 높이의 근거가 된다.
    @State private var contentHeight: CGFloat = 0

    /// 밖에서 온 시작 높이를 자리에 한 번이라도 반영했는지. 첫 프레임을 가릴지 정하는 근거다.
    @State private var didApplyInitialHeight = false

    /// 사용자가 시트를 끌어 자리를 직접 정한 적 있는지.
    /// 이게 서기 전까지는 뒤늦게 들어오는 시작 높이를 계속 따라간다.
    @State private var hasUserPlacedSheet = false

    /// 흰 판이 켜져 있는지. 값이 바뀔 때만 위로 알린다.
    @State private var isTopCovered = false

    /// `above` 가 지금 보이는지. 그리는 쪽은 이 값만 읽는다.
    /// 페이드는 값을 바꾸는 `syncAboveVisibility(_:)` 의 `withAnimation` 이 건다
    @State private var isAboveShown = true

    /// 끄는 동안의 이동량. 손을 떼면 선 자리에 접어 넣는다.
    @State private var dragTranslation: CGFloat = 0
    @State private var isDraggingSheet = false

    /// 시트 드래그가 실제로 시작된 시점의 `translation.height`.
    /// 제스처는 손을 댄 지점부터 누적되므로, 이 값을 빼야 시트가 한 프레임에 튀지 않는다.
    @State private var dragBaseline: CGFloat = 0

    /// 손 뗀 뒤 혼자 가는 동안의 도착 경로. `nil` 이면 서 있다
    @State private var coast: SheetCoast?

    var body: some View {
        GeometryReader { proxy in
            switch motion {
            case .free:
                freeSheet(in: proxy.size.height)
            case .snapping:
                snappingSheet(in: proxy.size.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

// MARK: - Free Init

extension MapBottomSheet where Footer == EmptyView {

    /// 내용 높이 그대로 그려두고 통째로 미는 시트.
    ///
    /// 높이를 안 바꾸므로 끄는 동안 안의 것을 다시 재지 않는다.
    /// `above` 는 시트 윗면 위에 얹혀 같이 움직인다.
    init(
        minVisibleHeight: CGFloat,
        initialVisibleHeight: CGFloat,
        topLimit: CGFloat,
        hideAboveAtTop: CGFloat? = nil,
        coverTopAtTop: CGFloat? = nil,
        onTopCoveredChange: ((Bool) -> Void)? = nil,
        openMenuFrames: [CGRect] = [],
        @ViewBuilder above: () -> Above,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.motion = .free(minVisibleHeight: minVisibleHeight)
        self.initialVisibleHeight = initialVisibleHeight
        self.topLimit = topLimit
        self.selection = nil
        self.onHeightChange = nil
        self.hideAboveAtTop = hideAboveAtTop
        self.coverTopAtTop = coverTopAtTop
        self.onTopCoveredChange = onTopCoveredChange
        self.openMenuFrames = openMenuFrames
        self.above = above()
        self.header = header()
        self.content = content()
        self.footer = EmptyView()
    }
}

// MARK: - Snapping Init

// 기본값 있는 @ViewBuilder 파라미터는 제네릭 추론이 걸리지 않아 편의 이니셜라이저로 나눠 둔다.

extension MapBottomSheet where Above == EmptyView {

    init(
        detents: [SheetDetent],
        selection: Binding<SheetDetent>,
        onHeightChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.motion = .snapping(detents)
        self.initialVisibleHeight = 0
        self.topLimit = 0
        self.selection = selection
        self.onHeightChange = onHeightChange
        self.hideAboveAtTop = nil
        self.coverTopAtTop = nil
        self.onTopCoveredChange = nil
        self.openMenuFrames = []
        self.above = EmptyView()
        self.header = header()
        self.content = content()
        self.footer = footer()
    }
}

extension MapBottomSheet where Above == EmptyView, Header == EmptyView, Footer == EmptyView {

    init(
        detents: [SheetDetent],
        selection: Binding<SheetDetent>,
        onHeightChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            detents: detents,
            selection: selection,
            onHeightChange: onHeightChange,
            header: { EmptyView() },
            content: content,
            footer: { EmptyView() }
        )
    }
}

extension MapBottomSheet where Above == EmptyView, Footer == EmptyView {

    init(
        detents: [SheetDetent],
        selection: Binding<SheetDetent>,
        onHeightChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            detents: detents,
            selection: selection,
            onHeightChange: onHeightChange,
            header: header,
            content: content,
            footer: { EmptyView() }
        )
    }
}

extension MapBottomSheet where Above == EmptyView, Header == EmptyView {

    init(
        detents: [SheetDetent],
        selection: Binding<SheetDetent>,
        onHeightChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            detents: detents,
            selection: selection,
            onHeightChange: onHeightChange,
            header: { EmptyView() },
            content: content,
            footer: footer
        )
    }
}

// MARK: - Layout

private extension MapBottomSheet {

    /// 자유 위치 배치. 카드 높이는 그대로 두고 통째로 민다.
    func freeSheet(in containerHeight: CGFloat) -> some View {
        card(in: containerHeight)
            // 시작 높이가 카드 높이보다 늦게 들어올 수 있다. 카드 높이는 그대로라 위 자리가 다시 안 불린다.
            // 화면 높이가 여러 번에 걸쳐 들어오므로 여기는 마지막 값까지 매번 따라가야 한다
            .onChange(of: initialVisibleHeight) { _, newHeight in
                followInitialHeight(newHeight)
            }
            // above 는 카드에 얹어야 밀린 카드를 따라간다.
            // 아래 .frame 은 담는 층 전체라, 그 뒤에 얹으면 화면 맨 위에 박힌다.
            // 카드의 clipShape 뒤라 시트 밖으로 나간 above 가 안 잘린다
            .overlay(alignment: .top) { aboveSlot }
            // 민 양이 아니라 카드 윗면의 y 를 직접 준다. 음수면 카드가 담는 층 위로 나가는데,
            // 그게 시트를 끝까지 올린 자리다. 0 으로 자르면 다시 안 올라간다
            .offset(y: currentTop(in: containerHeight))
            // 카드 높이를 재기 전에는 밀 양을 못 정해 카드가 엉뚱한 자리에 한 프레임 그려진다
            .opacity(isCardPlaced ? 1 : 0)
            // maxHeight 틀은 자식보다 작아지지 않는다. 카드가 담는 층보다 길면 이 틀도 같이 커져
            // 틀과 자식이 같은 크기가 되고 .bottom 정렬이 아무 일도 안 한다.
            // 그래서 윗면을 담는 층 y=0 에 맞추고, 오르내림은 위 .offset 하나가 맡는다
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .overlay { coastClock }
            .onChange(of: currentTop(in: containerHeight)) { _, top in
                notifyCoverChange(top: top)
            }
            // 위 onChange 옆에 얹지 않고 따로 둔다. 저쪽이 보는 currentTop 은 끄는 동안 매 프레임 바뀌어
            // 페이드가 프레임마다 다시 시작된다. 여기는 Bool 이라 문턱을 넘는 순간에만 불린다
            .onChange(of: isAboveVisible(in: containerHeight), initial: true) { _, isVisible in
                syncAboveVisibility(isVisible)
            }
    }

    /// 흰 배경과 모서리를 가진 시트 몸통.
    /// 높이는 내용 높이에서 계산해 못 박는다. 내용이 짧아도 `topLimit` 까지는 올라갈 수 있다
    func card(in containerHeight: CGFloat) -> some View {
        SheetCardInterior(header: header, content: content)
        // .frame·.fixedSize 를 만나기 전 내용 높이를 잰다.
        // 아래 .fixedSize 안쪽이라 위에서 주는 높이에 안 흔들린다. 자리를 옮기면 값이 오염된다
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
            if contentHeight != height {
                contentHeight = height
            }
            // 카드 높이는 재지 않고 여기서 계산한다. 재면 위에서 준 높이가 그대로 돌아와 그 값에 갇힌다.
            // 뒤 항은 장소가 적을 때도 시트가 topLimit 까지 올라가는 근거다
            let resolved = max(height, max(containerHeight - topLimit, 0))
            if cardHeight != resolved {
                cardHeight = resolved
            }
            // 내용이 짧아지면 보이는 높이가 카드보다 커진다. 그대로 두면 카드 아래로 빈 자리가 뜬다
            let clamped = clamp(visibleHeight, toCard: resolved)
            if visibleHeight != clamped {
                visibleHeight = clamped
            }
            // 시작 자리를 잡는 쪽이 이겨야 해서 자르기 뒤에 둔다.
            // 여기서는 방금 계산한 resolved 를 그대로 넘긴다. cardHeight 를 되읽지 않는다
            followInitialHeight(initialVisibleHeight, within: resolved)
            // 필터로 목록이 짧아지면 자리는 그대로인데 흰 판 조건만 바뀐다.
            // 아래 onChange 는 자리가 바뀔 때만 불려 이 경우를 놓친다
            notifyCoverChange(top: currentTop(in: containerHeight))
        }
        .frame(maxWidth: .infinity)
        // 세로만 내용 높이로 굳힌다. 이게 없으면 담는 자리 높이 제안을 그대로 받아 내용이 잘린다.
        // 아래 .frame(height:) 보다 앞이라야 안쪽 VStack 이 눌리지 않고 위 계측이 내용 높이를 낸다
        .fixedSize(horizontal: false, vertical: true)
        // background 앞이라야 흰 배경이 늘어난 높이를 채운다.
        // .offset 은 배치 크기를 안 바꾼다. 위 경계를 넘겨 끌면 보이는 높이가 카드보다 커지는데,
        // 높이를 카드에 묶어두면 카드 바닥이 담는 층 바닥 위로 올라와 화면 아래로 지도가 띠로 비친다.
        // 경계 안에서는 보이는 높이가 카드를 못 넘어 이 max 가 카드 높이를 그대로 낸다
        .frame(height: max(cardHeight, shownHeight(in: containerHeight)), alignment: .top)
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
        .simultaneousGesture(dragGesture())
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

    /// 단계 붙기 배치. 높이가 단계를 오간다.
    func snappingSheet(in containerHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 헤더가 드롭다운처럼 자기 밖 아래로 펼치는 걸 담을 수 있다.
            // 올려두지 않으면 뒤에 그려지는 본문이 그 펼침을 덮는다
            fixedTop
                .zIndex(1)
            snappingContent
            fixedBottom
        }
        .frame(height: currentHeight(in: containerHeight))
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
        .simultaneousGesture(snappingDragGesture(in: containerHeight))
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            onHeightChange?(height)
        }
        .onChange(of: sortedDetents, initial: true) { _, _ in
            snapSelectionIntoDetents()
        }
    }

    var fixedTop: some View {
        VStack(spacing: 0) {
            grabber
            header
        }
    }

    var fixedBottom: some View {
        footer
    }

    var grabber: some View {
        Capsule()
            .fill(Color.gray100)
            .frame(width: MapBottomSheetMetric.grabberWidth, height: MapBottomSheetMetric.grabberHeight)
            .frame(maxWidth: .infinity)
            .padding(.top, MapBottomSheetMetric.grabberTopInset)
            .padding(.bottom, MapBottomSheetMetric.grabberBottomInset)
    }

    /// 단계 붙기의 본문 자리. 자기 창보다 길면 잘려서 푸터를 덮지 않는다.
    ///
    /// **본문이 스크롤되지 않는다.** 자유 위치를 들이면서 `ScrollView` 와, 스크롤 위치로 시트 끌기를
    /// 막던 규칙(`가장 큰 단계가 아니거나 본문이 맨 위일 때만 끈다`)이 함께 빠졌다.
    /// 되살릴 때는 둘을 같이 되살려야 한다. `ScrollView` 만 넣으면 목록을 쓸 때 시트가 딸려 온다.
    /// 이 경로를 쓰는 화면이 아직 없어 지금 깨지는 것은 없다. DND-49 몫이다
    var snappingContent: some View {
        content
            .frame(maxWidth: .infinity, alignment: .top)
            // minHeight 를 안 주면 이 자리가 내용 높이만큼 벌어져 헤더와 푸터를 시트 밖으로 밀어낸다
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
            .clipped()
    }
}

// MARK: - SheetCardInterior

/// 높이 값을 읽지 않는 카드 안쪽.
/// 겉 층이 자리를 옮기는 동안 이 뷰의 body 는 다시 안 돈다
private struct SheetCardInterior<Header: View, Content: View>: View {
    let header: Header
    let content: Content

    var body: some View {
        VStack(spacing: 0) {
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
            // 헤더의 드롭다운 펼침을 본문이 덮지 않게 올린다. 위 snappingSheet 과 같은 이유다
            .zIndex(1)
            content
        }
    }
}

// MARK: - Free Offset

private extension MapBottomSheet {

    /// 가장 낮게 내렸을 때 화면에 남는 높이
    var minVisible: CGFloat {
        guard case let .free(minVisibleHeight) = motion else { return 0 }
        return minVisibleHeight
    }

    /// 지금 화면에 보이는 높이. 끄는 동안의 이동량과 경계 밖 눌림까지 반영한다
    func shownHeight(in containerHeight: CGFloat) -> CGFloat {
        // 위로 끌면 translation 이 음수다. 빼야 보이는 높이가 커진다
        banded(visibleHeight - dragTranslation, in: containerHeight)
    }

    /// 경계 안은 그대로 두고, 밖으로 나간 만큼만 고무줄로 눌러 돌려준다
    func banded(_ raw: CGFloat, in containerHeight: CGFloat) -> CGFloat {
        let bounded = clamp(raw, toCard: cardHeight)
        return bounded + SheetRubberBand.offset(
            overflow: raw - bounded,
            dimension: containerHeight
        )
    }

    /// 보이는 높이를 카드가 낼 수 있는 범위로 자른다. 카드가 최소치보다 짧으면 통째로 보인다
    func clamp(_ height: CGFloat, toCard cardHeight: CGFloat) -> CGFloat {
        min(max(height, minVisible), max(cardHeight, minVisible))
    }

    /// 시트 윗면의 담는 층 위 기준 y
    func currentTop(in containerHeight: CGFloat) -> CGFloat {
        containerHeight - shownHeight(in: containerHeight)
    }

    /// 카드가 자리를 잡았는지. 시작 높이를 반영했고 카드 높이까지 들어온 상태다.
    /// `cardHeight` 는 그리는 자리에서만 읽어 갱신 주기 안에서 옛 값으로 돌아갈 걱정이 없다
    var isCardPlaced: Bool {
        didApplyInitialHeight && cardHeight > 0
    }

    /// 밖에서 온 시작 높이를 따라도 되는지.
    /// 사용자가 자리를 정했거나 지금 끌고 있으면 안 된다. 손 밑에서 시트가 튀면 안 되기 때문이다
    var canFollowInitialHeight: Bool {
        !hasUserPlacedSheet && !isDraggingSheet
    }

    /// 시작 높이를 그대로 자리로 삼는다. 카드 높이를 모르는 자리에서 부른다.
    ///
    /// 담는 층이 아직 안 잡히면 시작 높이가 0 으로 온다. 그 값은 물지 않는다.
    /// 카드 범위로 자르지 않는 건 `cardHeight` 를 되읽지 않기 위해서다.
    /// `@State` 를 이런 콜백에서 되읽으면 같은 갱신 주기에 방금 쓴 값이 옛 값으로 돌아올 수 있다.
    /// 자르기는 그릴 때 `shownHeight(in:)` 이 이미 하고, 저장값 자체는 다음 계측에서 `clamp` 로 정리된다
    func followInitialHeight(_ height: CGFloat) {
        guard canFollowInitialHeight, height > 0 else { return }
        didApplyInitialHeight = true
        visibleHeight = height
    }

    /// 카드 높이를 아는 자리에서 부르는 쪽. 카드 범위로 잘라 넣는다
    func followInitialHeight(_ height: CGFloat, within cardHeight: CGFloat) {
        guard canFollowInitialHeight, height > 0, cardHeight > 0 else { return }
        didApplyInitialHeight = true
        visibleHeight = min(height, cardHeight)
    }

    func isAboveVisible(in containerHeight: CGFloat) -> Bool {
        guard let hideAboveAtTop else { return true }
        return currentTop(in: containerHeight) > hideAboveAtTop
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

    func notifyCoverChange(top: CGFloat) {
        guard let coverTopAtTop else { return }
        // 내용이 짧으면 시트가 천장까지 올라가도 빈 흰 카드 위에 흰 띠가 또 생겨 어색하다.
        // 카드 높이가 내용 높이로 잡혔을 때만 켠다. 짧으면 카드가 천장 기준 높이로 부풀어 있다
        let fillsToTop = contentHeight >= cardHeight
        let covered = fillsToTop && top <= coverTopAtTop
        guard covered != isTopCovered else { return }
        isTopCovered = covered
        onTopCoveredChange?(covered)
    }

    /// 손 뗀 순간의 자리를 모델에 굽는다. 애니메이션을 걸면 도착점과 다시 갈린다
    func bakeReleaseHeight(_ current: CGFloat) {
        visibleHeight = current
        dragTranslation = 0
    }

    func advanceCoast(at date: Date) {
        guard let coast else { return }
        let next = coast.height(at: date)
        if visibleHeight != next.value {
            visibleHeight = next.value
        }
        if next.isFinished {
            self.coast = nil
        }
    }

    @ViewBuilder
    var coastClock: some View {
        if coast != nil {
            TimelineView(.animation) { context in
                Color.clear
                    .frame(width: 0, height: 0)
                    .onChange(of: context.date) { _, date in
                        advanceCoast(at: date)
                    }
                    .onAppear {
                        advanceCoast(at: context.date)
                    }
            }
        }
    }
}

// MARK: - Snapping Height

private extension MapBottomSheet {

    func currentHeight(in containerHeight: CGFloat) -> CGFloat {
        let base = (selection?.wrappedValue ?? smallestDetent).height(in: containerHeight)
        let dragged = base - dragTranslation
        return min(max(dragged, minHeight(in: containerHeight)), maxHeight(in: containerHeight))
    }

    func minHeight(in containerHeight: CGFloat) -> CGFloat {
        smallestDetent.height(in: containerHeight)
    }

    func maxHeight(in containerHeight: CGFloat) -> CGFloat {
        largestDetent.height(in: containerHeight)
    }
}

// MARK: - Detent

private extension MapBottomSheet {

    var sortedDetents: [SheetDetent] {
        guard case let .snapping(detents) = motion else { return [] }
        return detents.sorted { $0.fraction < $1.fraction }
    }

    var largestDetent: SheetDetent {
        sortedDetents.last ?? .fraction(1)
    }

    var smallestDetent: SheetDetent {
        sortedDetents.first ?? .fraction(0)
    }

    func nearestDetent(to height: CGFloat, in containerHeight: CGFloat) -> SheetDetent {
        sortedDetents.min {
            abs($0.height(in: containerHeight) - height) < abs($1.height(in: containerHeight) - height)
        } ?? smallestDetent
    }

    /// `detents` 만 갈아끼우면 `selection` 이 옛 값으로 남아 시트가 어느 단계에도 없는 높이에 선다.
    /// 목록 밖 값이면 가장 가까운 단계로 다시 붙인다.
    ///
    /// 컨테이너 높이 없이 비교할 수 있게 기준 높이 `1` 을 쓴다. `height(in: 1)` 은 곧 `fraction` 이다.
    func snapSelectionIntoDetents() {
        guard case let .snapping(detents) = motion, let selection else { return }
        guard !detents.isEmpty, !detents.contains(selection.wrappedValue) else { return }
        selection.wrappedValue = nearestDetent(to: selection.wrappedValue.fraction, in: 1)
    }
}

// MARK: - Drag

private extension MapBottomSheet {

    /// 자유 위치의 손짓. `.global` 좌표라 이동량을 그대로 민 양에 쓴다.
    func dragGesture() -> some Gesture {
        // 기준을 화면 전체로 잡는다. 기본값(.local)은 제스처가 붙은 시트 자기 좌표계로 재는데,
        // 시트는 이 손짓 때문에 매 프레임 움직인다. 기준이 손가락을 따라가
        // 이동 거리가 실제보다 작게 나오고, 프레임마다 기준이 달라져 값이 튄다
        DragGesture(
            minimumDistance: MapBottomSheetMetric.minimumDragDistance,
            coordinateSpace: .global
        )
            .onChanged { value in
                if !isDraggingSheet {
                    guard shouldBeginSheetDrag(value) else { return }
                    isDraggingSheet = true
                    coast = nil
                    // 시작 시점의 누적 이동량을 기준으로 잡는다. 이후 이동은 전부 이 값과의 차다
                    dragBaseline = value.translation.height
                }

                dragTranslation = value.translation.height - dragBaseline
            }
            .onEnded { value in
                guard isDraggingSheet else { return }
                isDraggingSheet = false

                // 여기서 세운다. onChanged 가 아니라 손짓이 끝난 뒤여야 하는 이유는,
                // 사용자가 정한 자리가 아래 visibleHeight 로 확정되는 시점이 여기라서다.
                // onChanged 에서 세우면 자리는 아직 끄는 중인데 시작 높이만 끊겨,
                // 손짓이 취소된 경우 옛 자리에 갇힌다. 끄는 동안은 canFollowInitialHeight 가 막는다
                hasUserPlacedSheet = true

                // 손 뗀 뒤 아이폰 기본 스크롤과 같은 감속으로 미끄러진다.
                // predictedEndTranslation 은 정의상 속도의 1/4 이라 기본 스크롤의 절반밖에 안 간다.
                // 미끄러질 거리가 속도 ÷ k 라서 아래 곡선의 출발 기울기가 곧 손가락 속도가 된다.
                // 그래서 속도를 애니메이션에 따로 넘길 필요가 없다
                let velocity = Double(value.velocity.height)
                let decelerationRate = MapBottomSheetMetric.decelerationRate
                let projection = CGFloat(velocity / 1000 * decelerationRate / (1 - decelerationRate))

                let current = visibleHeight - dragTranslation
                let raw = current - projection
                let settled = clamp(raw, toCard: cardHeight)
                dragBaseline = 0

                // 지금 자리도 목적지도 경계 안이면 지금까지의 움직임 그대로다
                let staysInside = raw == settled && current == clamp(current, toCard: cardHeight)

                guard staysInside else {
                    settleFromOutside(to: settled, from: current, velocity: velocity)
                    return
                }

                settleInside(to: settled, from: current, velocity: velocity)
            }
    }

    /// 지금 자리도 목적지도 경계 안일 때. 손가락 세기를 이어받은 감쇠 곡선으로 미끄러진다.
    ///
    /// 목적지가 잘리는 경우는 `settleFromOutside` 로 빠지므로, 여기서 갈 거리는 언제나 미끄러질 거리다.
    /// 곡선 x(t) = D(1 − e^{−kt}) 의 출발 기울기가 D · k 라, k 를 |속도| ÷ |거리| 로 내면
    /// 출발 기울기가 손가락 속도 그대로 남고, k 는 늘 2.004 가 된다
    func settleInside(to settled: CGFloat, from current: CGFloat, velocity: Double) {
        let travel = abs(Double(settled - current))
        bakeReleaseHeight(current)

        guard travel >= MapBottomSheetMetric.minimumDecayTravel else {
            visibleHeight = settled
            return
        }

        // 목적지가 안 잘려 travel 이 늘 |속도| × 0.499 라, 하한 없이 |속도| ÷ travel 이 늘 2.004 다
        let decayConstant = abs(velocity) / travel
        coast = .decay(
            start: current,
            end: settled,
            startedAt: .now,
            decayConstant: decayConstant
        )
    }

    /// 경계를 넘는다. 용수철에 손가락 속도를 실어 보내면 경계를 지나쳤다 스스로 돌아온다.
    ///
    /// 위로 튕기면 `velocity` 가 음수고 `settled - current` 는 양수라,
    /// `-velocity / distance` 가 양수가 되어 보이는 높이가 커지는 쪽으로 출발한다
    func settleFromOutside(to settled: CGFloat, from current: CGFloat, velocity: Double) {
        bakeReleaseHeight(current)
        let distance = Double(settled - current)
        let initialVelocity = distance == 0 ? 0 : -velocity / distance
        coast = .spring(
            start: current,
            end: settled,
            startedAt: .now,
            initialVelocity: initialVelocity
        )
    }

    /// 단계 붙기의 손짓. 이동량은 통째로 시트 높이 몫이다.
    func snappingDragGesture(in containerHeight: CGFloat) -> some Gesture {
        // 좌표 기준은 자유 위치와 같은 이유로 화면 전체다
        DragGesture(
            minimumDistance: MapBottomSheetMetric.minimumDragDistance,
            coordinateSpace: .global
        )
            .onChanged { value in
                if !isDraggingSheet {
                    guard shouldBeginSheetDrag(value) else { return }
                    isDraggingSheet = true
                    dragBaseline = value.translation.height
                }

                dragTranslation = value.translation.height - dragBaseline
            }
            .onEnded { value in
                guard isDraggingSheet else { return }
                isDraggingSheet = false
                settleToDetent(after: value, in: containerHeight)
            }
    }

    /// 손을 뗀 뒤 붙을 단계를 정한다.
    func settleToDetent(after value: DragGesture.Value, in containerHeight: CGFloat) {
        let predictedTranslation = value.predictedEndTranslation.height - dragBaseline
        dragBaseline = 0

        // 단계에 붙어야 해서, 살짝 튕긴 손짓을 놓치지 않게 속도가 섞인 예상 종점으로 잰다
        let base = (selection?.wrappedValue ?? smallestDetent).height(in: containerHeight)
        let target = nearestDetent(to: base - predictedTranslation, in: containerHeight)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            selection?.wrappedValue = target
            dragTranslation = 0
        }
    }

    /// 시트 드래그를 시작할지 정한다. 한 번 시작한 뒤에는 다시 묻지 않아 손짓 중간에 끊기지 않는다.
    func shouldBeginSheetDrag(_ value: DragGesture.Value) -> Bool {
        let vertical = abs(value.translation.height)
        let horizontal = abs(value.translation.width)

        // 손짓 우선순위는 ScrollView 와 안 갈린다.
        // 시작점이 열린 메뉴 안이면 메뉴만 스크롤하고 시트는 안 민다
        if openMenuFrames.contains(where: { $0.contains(value.startLocation) }) {
            return false
        }

        // 세로가 가로보다 확실히 클 때만. 썸네일 가로 스크롤에 시트가 딸려오는 걸 막는다
        return vertical > horizontal * MapBottomSheetMetric.verticalDominance
    }
}

// MARK: - SheetCoast

/// 손 뗀 뒤 시트가 혼자 가는 동안의 자리.
/// 도착점은 여기에만 두고, 화면에 쓰는 값은 `visibleHeight` 다
private enum SheetCoast {
    case decay(start: CGFloat, end: CGFloat, startedAt: Date, decayConstant: Double)
    case spring(start: CGFloat, end: CGFloat, startedAt: Date, initialVelocity: Double)

    func height(at date: Date) -> (value: CGFloat, isFinished: Bool) {
        switch self {
        case let .decay(start, end, startedAt, decayConstant):
            let time = date.timeIntervalSince(startedAt)
            let remaining = exp(-decayConstant * time)
            let travel = Double(end - start)
            // 남은 거리가 0.5pt 미만이면 끝난 것으로 본다
            if abs(travel) * remaining < MapBottomSheetMetric.minimumDecayTravel {
                return (end, true)
            }
            return (start + CGFloat(travel * (1 - remaining)), false)

        case let .spring(start, end, startedAt, initialVelocity):
            let duration = MapBottomSheetMetric.edgeReturnDuration
            let time = date.timeIntervalSince(startedAt)
            if time >= duration {
                return (end, true)
            }
            let omega = 10 / duration
            let progress = 1 - (1 + (omega - initialVelocity) * time) * exp(-omega * time)
            return (start + (end - start) * CGFloat(progress), false)
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
    let detents: [SheetDetent]
    let rowCount: Int

    @State private var selection: SheetDetent
    @State private var sheetHeight: CGFloat = 0

    init(detents: [SheetDetent], rowCount: Int = 8) {
        self.detents = detents
        self.rowCount = rowCount
        _selection = State(initialValue: detents.first ?? .fraction(0.5))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.gray200
                .ignoresSafeArea()

            Text("시트 높이 \(Int(sheetHeight))")
                .typography(.caption1M)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, Spacing.s32)

            MapBottomSheet(
                detents: detents,
                selection: $selection,
                onHeightChange: { sheetHeight = $0 }
            ) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("저장한 장소")
                        .typography(.title3SB)
                        .foregroundStyle(Color.textPrimary)
                        .padding(.horizontal, Spacing.s20)
                        .padding(.bottom, Spacing.s12)

                    ForEach(0..<rowCount, id: \.self) { index in
                        MapBottomSheetPreviewRow(index: index)
                        Divider()
                            .foregroundStyle(Color.borderWeak)
                    }
                }
                .padding(.bottom, Spacing.s32)
            }
        }
    }
}

// a08 — 지도 위 기본 2단(50% / 13%)
#Preview("2단 기본") {
    MapBottomSheetPreviewHost(detents: [.fraction(0.5), .fraction(0.13)])
}

// a13 · a14 — 접힘/펼침 사이에 중간 단계를 하나 더 둔 3단
#Preview("3단") {
    MapBottomSheetPreviewHost(detents: [.fraction(0.9), .fraction(0.5), .fraction(0.13)])
}

// a10 · b04 · c01 — 단계 붙기는 목록을 밀지 않아 창보다 긴 내용이 잘린다. DND-49 에서 다시 본다
#Preview("긴 리스트 잘림") {
    MapBottomSheetPreviewHost(
        detents: [.fraction(0.9), .fraction(0.5), .fraction(0.13)],
        rowCount: 50
    )
}

// 저장한 장소 시트 — 카드를 통째로 민다. 행 20개라 카드가 화면보다 길다
#Preview("자유 위치") {
    ZStack(alignment: .bottom) {
        Color.gray200
            .ignoresSafeArea()

        MapBottomSheet(
            minVisibleHeight: 115,
            initialVisibleHeight: 340,
            topLimit: 56,
            hideAboveAtTop: 400,
            coverTopAtTop: 56
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
                ForEach(0 ..< 20, id: \.self) { index in
                    MapBottomSheetPreviewRow(index: index)
                    Divider()
                }
            }
        }
    }
}
#endif
