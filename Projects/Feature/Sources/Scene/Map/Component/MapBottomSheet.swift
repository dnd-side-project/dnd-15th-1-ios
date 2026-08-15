//
//  MapBottomSheet.swift
//  Dulpick
//
//  `BottomSheet.swift` 와 따로 둔다. 이름은 닮았지만 다른 물건이다.
//
//  `BottomSheet` 는 `.bottomSheet(isPresented:)` 수식어다.
//  딤을 깔고 바깥을 탭하면 닫히는 모달이고, 높이는 내용에 맞춰 고정된다.
//
//  `MapBottomSheet` 는 딤이 없다. 뒤에 깔린 지도를 계속 조작할 수 있어야 하고,
//  단계 여러 개 사이를 끌어서 오간다. 떴다 사라지는 게 아니라 화면에 상주한다.
//
//  표시 방식(overlay + 딤 + 트랜지션)을 `BottomSheet` 가 자기가 소유하고 있어서,
//  그걸 감싸 재사용할 수 있는 구조가 아니다. 껍데기 값(모서리 32, 잡이 막대 50 × 6)은 이미 맞춰뒀다.
//

import SharedDesignSystem
import SwiftUI

// MARK: - SheetDetent

/// 바텀시트가 멈추는 단계. 담긴 컨테이너 높이 대비 비율이다.
public enum SheetDetent: Hashable {
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

// MARK: - MapBottomSheetMetric

private enum MapBottomSheetMetric {
    static let cornerRadius: CGFloat = 32
    static let grabberWidth: CGFloat = 50
    static let grabberHeight: CGFloat = 6
    static let grabberTopInset: CGFloat = 14
    static let grabberBottomInset: CGFloat = 13
    static let shadowRadius: CGFloat = 12
    static let shadowOpacity: CGFloat = 0.08
    static let shadowOffsetY: CGFloat = -4
    static let minimumDragDistance: CGFloat = 4

    /// 시트 드래그로 인정하는 세로 우세 비율. 가로 스크롤을 쓸다 시트가 딸려오는 걸 막는다.
    static let verticalDominance: CGFloat = 1.5
}

// MARK: - MapBottomSheet

/// `presentationDetents` 를 쓰지 않는 자체 바텀시트.
///
/// 딤이 없고 아래층이 그대로 조작되어야 해서 `ZStack` 의 위층에 얹어 쓴다.
/// 시트 밖 영역은 배경이 없어 터치를 가로채지 않는다.
///
/// ```swift
/// ZStack(alignment: .bottom) {
///     MapView()
///     MapBottomSheet(detents: [.fraction(0.5), .fraction(0.13)], selection: $detent) {
///         savedPlaceList
///     }
/// }
/// ```
public struct MapBottomSheet<Content: View>: View {

    // 내부 ScrollView 를 시트가 직접 갖는다.
    // 호출부가 scrollDisabled·onScrollGeometryChange 를 매번 붙일 필요 없이 내용만 넘기면 되기 때문이다.
    private let detents: [SheetDetent]
    @Binding private var selection: SheetDetent
    private let onHeightChange: ((CGFloat) -> Void)?
    private let content: Content

    @State private var dragTranslation: CGFloat = 0
    @State private var scrollOffset: CGFloat = 0
    @State private var isDraggingSheet = false

    /// 시트 드래그가 실제로 시작된 시점의 `translation.height`.
    /// 제스처는 손을 댄 지점부터 누적되므로, 이 값을 빼야 시트가 한 프레임에 튀지 않는다.
    @State private var dragBaseline: CGFloat = 0

    /// 잡이 막대 · 헤더 · 푸터에서 시작한 손짓인지. 그 자리는 스크롤과 무관하게 늘 시트 드래그다.
    @State private var isDragFromFixedArea = false

    public init(
        detents: [SheetDetent],
        selection: Binding<SheetDetent>,
        onHeightChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.detents = detents
        self._selection = selection
        self.onHeightChange = onHeightChange
        self.content = content()
    }

    public var body: some View {
        GeometryReader { proxy in
            sheet(in: proxy.size.height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - Layout

private extension MapBottomSheet {

    func sheet(in containerHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            grabber
            scrollableContent
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
        .simultaneousGesture(dragGesture(in: containerHeight))
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            onHeightChange?(height)
        }
    }

    var grabber: some View {
        Capsule()
            .fill(Color.gray300)
            .frame(width: MapBottomSheetMetric.grabberWidth, height: MapBottomSheetMetric.grabberHeight)
            .frame(maxWidth: .infinity)
            .padding(.top, MapBottomSheetMetric.grabberTopInset)
            .padding(.bottom, MapBottomSheetMetric.grabberBottomInset)
    }

    var scrollableContent: some View {
        ScrollView {
            content
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(!isExpanded)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
            scrollOffset = y
        }
    }
}

// MARK: - Detent

private extension MapBottomSheet {

    var sortedDetents: [SheetDetent] {
        let sorted = detents.sorted { $0.fraction < $1.fraction }
        return sorted.isEmpty ? [selection] : sorted
    }

    var largestDetent: SheetDetent {
        sortedDetents.last ?? selection
    }

    var smallestDetent: SheetDetent {
        sortedDetents.first ?? selection
    }

    /// 가장 큰 단계에서만 내부 리스트가 스크롤된다.
    var isExpanded: Bool {
        selection == largestDetent
    }

    /// 가장 큰 단계가 아니거나, 리스트가 맨 위일 때만 시트를 끈다.
    var canDragSheet: Bool {
        !isExpanded || scrollOffset <= 0
    }

    func currentHeight(in containerHeight: CGFloat) -> CGFloat {
        let dragged = selection.height(in: containerHeight) - dragTranslation
        let minHeight = smallestDetent.height(in: containerHeight)
        let maxHeight = largestDetent.height(in: containerHeight)
        return min(max(dragged, minHeight), maxHeight)
    }

    func nearestDetent(to height: CGFloat, in containerHeight: CGFloat) -> SheetDetent {
        sortedDetents.min {
            abs($0.height(in: containerHeight) - height) < abs($1.height(in: containerHeight) - height)
        } ?? selection
    }
}

// MARK: - Drag

private extension MapBottomSheet {

    /// 잡이 막대 · 헤더 · 푸터에 얹는 표시용 제스처. 이동량은 건드리지 않고 시작 위치만 남긴다.
    /// `minimumDistance` 가 0 이라 시트 드래그(4pt)보다 먼저 켜진다.
    var fixedAreaMarker: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                isDragFromFixedArea = true
            }
            .onEnded { _ in
                isDragFromFixedArea = false
            }
    }

    func dragGesture(in containerHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: MapBottomSheetMetric.minimumDragDistance)
            .onChanged { value in
                if !isDraggingSheet {
                    guard shouldBeginSheetDrag(value) else { return }
                    isDraggingSheet = true
                    // 시작 시점의 누적 이동량을 기준으로 잡는다. 이후 이동은 전부 이 값과의 차다
                    dragBaseline = value.translation.height
                }
                dragTranslation = value.translation.height - dragBaseline
            }
            .onEnded { value in
                isDragFromFixedArea = false
                guard isDraggingSheet else { return }
                isDraggingSheet = false

                // 이동량만 보면 살짝 튕긴 손짓을 놓친다. 속도가 섞인 예상 종점으로 붙일 단계를 고른다
                let predictedTranslation = value.predictedEndTranslation.height - dragBaseline
                let predictedHeight = selection.height(in: containerHeight) - predictedTranslation
                let target = nearestDetent(to: predictedHeight, in: containerHeight)

                dragBaseline = 0

                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    selection = target
                    dragTranslation = 0
                }
            }
    }

    /// 시트 드래그를 시작할지 정한다. 한 번 시작한 뒤에는 다시 묻지 않아 손짓 중간에 끊기지 않는다.
    func shouldBeginSheetDrag(_ value: DragGesture.Value) -> Bool {
        let vertical = abs(value.translation.height)
        let horizontal = abs(value.translation.width)

        // 세로가 가로보다 확실히 클 때만. 썸네일 가로 스크롤에 시트가 딸려오는 걸 막는다
        guard vertical > horizontal * MapBottomSheetMetric.verticalDominance else { return false }

        // 잡이 막대 · 헤더 · 푸터는 스크롤이 없어 늘 시트 드래그다
        guard !isDragFromFixedArea else { return true }

        guard canDragSheet else { return false }

        // 가장 큰 단계에서 위로 미는 건 시트가 아니라 본문 스크롤이다
        return !(isExpanded && value.translation.height < 0)
    }
}

// MARK: - Preview

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

// a10 · b04 · c01 — 펼친 단계에서만 리스트가 스크롤되는지 확인
#Preview("긴 리스트 스크롤") {
    MapBottomSheetPreviewHost(
        detents: [.fraction(0.9), .fraction(0.5), .fraction(0.13)],
        rowCount: 50
    )
}
