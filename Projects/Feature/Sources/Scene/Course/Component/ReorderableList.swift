//
//  ReorderableList.swift
//  Dulpick
//
//  Created by 이인호 on 8/14/26.
//

import SharedDesignSystem
import SwiftUI

// MARK: - Metric

// 시안 c04 에서 잰 값. 드롭 위치를 고정 피치로 계산하므로 행 높이와 간격은 바뀌면 안 된다.
private enum ReorderableListMetric {
    static let rowHeight: CGFloat = 81
    static let rowSpacing: CGFloat = 20
    static let cornerRadius: CGFloat = 12

    /// 보이는 손잡이 아이콘 크기. 카드 왼쪽에서 이 절반 + 좌우 여백만큼이 아이콘 중심이다.
    static let handleIconSize: CGFloat = 24
    /// 손잡이 터치 범위. 아이콘은 이 범위의 위쪽 가운데에 놓인다.
    static let handleHitSize: CGFloat = 40

    // 평상시 그림자. 시안 c04 의 카드 가장자리 밝기 감쇠(위 5 · 옆 11 · 아래 17)에 맞춘 값이다
    static let restShadowRadius: CGFloat = 3
    static let restShadowOffsetY: CGFloat = 2
    static let restShadowOpacity: CGFloat = 0.08

    // 시안 c05 에서 그림자 번짐을 빼고 테두리 획만 재면 끄는 카드는 정지 카드와 폭도 높이도 같다(353 × 81).
    // 가로 중심만 10 왼쪽으로 갈 뿐이고, 들렸다는 느낌은 전부 그림자가 낸다. 그래서 확대는 없다.
    static let liftOffsetX: CGFloat = -10
    static let liftShadowRadius: CGFloat = 8
    static let liftShadowOffsetY: CGFloat = 4
    static let liftShadowOpacity: CGFloat = 0.12

    /// 점선 중심 x. 카드 왼쪽 테두리 기준이다. 손잡이 중심(32) 과 다르다.
    static let connectorCenterX: CGFloat = 16
    /// 점선이 카드에 닿지 않게 위아래로 한 주기씩 띄운다. 간격 20 안에 점 3개가 남는다.
    static let connectorInset: CGFloat = DottedVerticalLine.dotSpacing
    /// 점선 경로 길이. 경로 끝에 딱 걸리는 점은 그려지지 않아서 마지막 점 뒤로 반 주기를 더 준다.
    static let connectorLength: CGFloat = rowSpacing - connectorInset * 2 + DottedVerticalLine.dotSpacing / 2

    /// 행 하나가 차지하는 세로 거리. 드롭 위치 계산의 단위다.
    static let pitch: CGFloat = rowHeight + rowSpacing
}

// MARK: - Alignment

private extension VerticalAlignment {

    /// 장소명 첫 줄의 세로 중심. 손잡이와 우측 슬롯이 이 선에 선다.
    ///
    /// 시안 c04 에서 두 아이콘은 카드 한가운데가 아니라 이름줄 한가운데에 있다.
    /// 픽셀 offset 을 박지 않고 이름 `Text` 자신의 세로 중심을 기준선으로 올려서,
    /// 타이포가 바뀌어도 아이콘 중심이 따라오게 한다.
    /// 주소가 두 줄이 되면 글자 블록은 아래로만 자라므로 이 선은 움직이지 않는다.
    ///
    /// 기본값이 각 뷰의 세로 중심이라 아이콘 쪽은 자기 중심을 그대로 쓴다.
    struct RowTitleLine: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let rowTitleLine = VerticalAlignment(RowTitleLine.self)
}

// MARK: - ReorderableList

/// 왼쪽 손잡이로만 끌어서 순서를 바꾸는 리스트.
///
/// `List` 의 `onMove` 를 쓰지 않는다. 카드 사이 간격·끄는 중 그림자를 시안대로 내려면
/// 행 높이 81 + 간격 20 을 고정값으로 두고 직접 계산해야 한다.
///
/// 배열은 부품이 고치지 않는다. 끄는 동안의 오프셋만 부품이 들고 있다가
/// 손을 뗄 때 `onMove(from:to:)` 로 확정된 자리만 올린다. 순서를 실제로 바꾸는 것은 부르는 쪽이다.
///
/// ```swift
/// ReorderableList(
///     items: store.places,
///     onMove: { from, to in store.send(.placeMoved(from: from, to: to)) },
///     rowTitle: \.name,
///     rowSubtitle: \.address
/// ) { place in
///     deleteButton(place)
/// }
/// ```
struct ReorderableList<Item: Identifiable, Trailing: View>: View {
    private let items: [Item]
    private let onMove: (Int, Int) -> Void
    private let rowTitle: (Item) -> String
    private let rowSubtitle: (Item) -> String
    private let trailing: (Item) -> Trailing

    @State private var draggingItemID: Item.ID?
    @State private var dragSourceIndex: Int?
    @State private var dragTranslation: CGFloat = 0
    @State private var dropIndex: Int = 0

    init(
        items: [Item],
        onMove: @escaping (Int, Int) -> Void,
        rowTitle: @escaping (Item) -> String,
        rowSubtitle: @escaping (Item) -> String,
        @ViewBuilder trailing: @escaping (Item) -> Trailing
    ) {
        self.items = items
        self.onMove = onMove
        self.rowTitle = rowTitle
        self.rowSubtitle = rowSubtitle
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: ReorderableListMetric.rowSpacing) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                row(for: item, at: index)
            }
        }
        .background(alignment: .topLeading) {
            connectors
        }
        // 끄는 중에 밖에서 그 항목이 지워지면 손잡이째 사라져 `onEnded` 가 오지 않는다.
        // 그대로 두면 없는 id 를 가리킨 채 나머지 행이 한 칸 밀린 모양으로 굳는다.
        .onChange(of: items.map(\.id)) { _, ids in
            guard let draggingItemID, !ids.contains(draggingItemID) else { return }
            withAnimation(.snappy(duration: 0.2)) {
                resetDragState()
            }
        }
    }
}

// MARK: - Row

private extension ReorderableList {

    func row(for item: Item, at index: Int) -> some View {
        let isDragging = draggingItemID == item.id

        // 평상시에도 옅은 그림자가 있다. 끄는 동안에는 같은 그림자가 진해지고 넓어진다.
        return card(for: item, at: index)
            .shadow(
                color: .commonBlack.opacity(
                    isDragging
                        ? ReorderableListMetric.liftShadowOpacity
                        : ReorderableListMetric.restShadowOpacity
                ),
                radius: isDragging
                    ? ReorderableListMetric.liftShadowRadius
                    : ReorderableListMetric.restShadowRadius,
                y: isDragging
                    ? ReorderableListMetric.liftShadowOffsetY
                    : ReorderableListMetric.restShadowOffsetY
            )
            .offset(
                x: isDragging ? ReorderableListMetric.liftOffsetX : 0,
                y: offsetY(at: index, isDragging: isDragging)
            )
            .zIndex(isDragging ? 1 : 0)
    }

    func card(for item: Item, at index: Int) -> some View {
        HStack(alignment: .rowTitleLine, spacing: Spacing.s8) {
            handle(for: item, at: index)
                .alignmentGuide(.rowTitleLine) { $0[VerticalAlignment.center] }

            VStack(alignment: .leading, spacing: Spacing.s4) {
                Text(rowTitle(item))
                    .typography(.body1SB)
                    .foregroundStyle(Color.textPrimary)
                    // 이 한 줄의 중심이 카드 안 세로 기준선이 된다
                    .alignmentGuide(.rowTitleLine) { $0[VerticalAlignment.center] }

                Text(rowSubtitle(item))
                    .typography(.caption1R)
                    .foregroundStyle(Color.textTertiary)
            }
            .lineLimit(1)

            Spacer(minLength: Spacing.s8)

            trailing(item)
                .alignmentGuide(.rowTitleLine) { $0[VerticalAlignment.center] }
        }
        .padding(.horizontal, Spacing.s20)
        .frame(height: ReorderableListMetric.rowHeight)
        .background(Color.commonWhite)
        .clipShape(RoundedRectangle(cornerRadius: ReorderableListMetric.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ReorderableListMetric.cornerRadius, style: .continuous)
                .strokeBorder(Color.borderDefault, lineWidth: 1)
        }
    }

    // 카드 본체가 아니라 이 손잡이에만 제스처를 단다.
    //
    // 레이아웃 자리는 보이는 아이콘 24 그대로 두고, 터치 범위 40 은 overlay 로 얹는다.
    // 40 을 레이아웃에 넣으면 아이콘 중심이 카드 왼쪽에서 32 를 벗어난다.
    // overlay 를 위쪽에 붙여 아이콘이 터치 범위의 위쪽 가운데에 오게 한다.
    func handle(for item: Item, at index: Int) -> some View {
        Image.move
            .renderingMode(.template)
            .resizable()
            .frame(
                width: ReorderableListMetric.handleIconSize,
                height: ReorderableListMetric.handleIconSize
            )
            .foregroundStyle(Color.brandPrimary)
            .overlay(alignment: .top) {
                Color.clear
                    .frame(
                        width: ReorderableListMetric.handleHitSize,
                        height: ReorderableListMetric.handleHitSize
                    )
                    .contentShape(Rectangle())
                    .gesture(dragGesture(for: item, at: index))
            }
    }
}

// MARK: - Connector

private extension ReorderableList {

    /// 카드 사이 빈 구간을 잇는 세로 점선.
    ///
    /// 카드 뒤 고정 배치라 끄는 카드를 따라가지 않는다. 끄는 동안의 점선 처리는 시안에 없어
    /// 제자리에 두는 쪽을 골랐다. 마지막 카드 아래에는 그리지 않는다.
    @ViewBuilder
    var connectors: some View {
        ForEach(0 ..< max(items.count - 1, 0), id: \.self) { index in
            DottedVerticalLine(color: .borderDefault)
                .frame(height: ReorderableListMetric.connectorLength)
                .offset(
                    x: ReorderableListMetric.connectorCenterX - DottedVerticalLine.lineWidth / 2,
                    y: ReorderableListMetric.rowHeight
                        + ReorderableListMetric.connectorInset
                        + ReorderableListMetric.pitch * CGFloat(index)
                )
        }
    }
}

// MARK: - Drag

private extension ReorderableList {

    // 끄는 카드가 손가락을 따라 움직이므로 local 좌표계는 되먹임이 생긴다. global 을 쓴다.
    func dragGesture(for item: Item, at index: Int) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .global)
            .onChanged { value in
                // 이미 다른 카드를 끄는 중이라면 이 손잡이의 이동량은 남의 카드 것이다.
                // 막지 않으면 두 번째 손가락이 첫 번째 카드를 움직인다.
                guard draggingItemID == nil || draggingItemID == item.id else { return }

                if draggingItemID == nil {
                    draggingItemID = item.id
                    dragSourceIndex = index
                    dropIndex = index
                }

                guard let source = dragSourceIndex else { return }

                dragTranslation = clampedTranslation(value.translation.height, from: source)

                let nextDropIndex = targetIndex(for: dragTranslation, from: source)
                if nextDropIndex != dropIndex {
                    withAnimation(.snappy(duration: 0.2)) {
                        dropIndex = nextDropIndex
                    }
                }
            }
            .onEnded { _ in
                guard draggingItemID == item.id else { return }

                // 부르는 쪽의 배열 변경과 수동 오프셋 해제가 같은 곡선으로 상쇄되어야
                // 카드가 튀지 않는다. 한 트랜잭션 안에서 같이 바꾼다.
                withAnimation(.snappy(duration: 0.2)) {
                    if let move = confirmedMove(for: item) {
                        onMove(move.from, move.to)
                    }
                    resetDragState()
                }
            }
    }

    /// 손을 뗀 순간 실제로 올릴 이동. 올릴 게 없으면 `nil`.
    ///
    /// 끄는 도중 밖에서 `items` 가 바뀌었을 수 있어 시작할 때 잡은 인덱스를 믿지 않는다.
    /// 지금 배열에서 다시 찾아, 항목이 사라졌거나 자리가 밀렸거나 목적지가 범위를 벗어나면
    /// 이동을 포기한다. 확정을 건너뛰어도 상태는 풀리므로 화면은 현재 배열 그대로 돌아온다.
    func confirmedMove(for item: Item) -> (from: Int, to: Int)? {
        guard let source = items.firstIndex(where: { $0.id == item.id }),
              source == dragSourceIndex,
              items.indices.contains(dropIndex),
              dropIndex != source
        else { return nil }

        return (source, dropIndex)
    }

    /// 끌지 않는 행이 비켜주는 양. 지나온 행만 한 칸씩 반대로 민다.
    func offsetY(at index: Int, isDragging: Bool) -> CGFloat {
        guard let source = dragSourceIndex else { return 0 }
        if isDragging { return dragTranslation }

        if source < dropIndex, index > source, index <= dropIndex {
            return -ReorderableListMetric.pitch
        }
        if dropIndex < source, index >= dropIndex, index < source {
            return ReorderableListMetric.pitch
        }
        return 0
    }

    /// 리스트 밖으로 카드가 빠져나가지 않게 이동량을 위아래 끝에 묶는다.
    /// 항목이 하나뿐이면 위아래 여유가 0 이라 제자리에 머문다.
    func clampedTranslation(_ translation: CGFloat, from source: Int) -> CGFloat {
        let minTranslation = -ReorderableListMetric.pitch * CGFloat(source)
        let maxTranslation = ReorderableListMetric.pitch * CGFloat(max(items.count - 1 - source, 0))
        return min(max(translation, minTranslation), maxTranslation)
    }

    /// 이동량을 행 피치로 나눠 반올림한 칸 수가 곧 목적지다.
    func targetIndex(for translation: CGFloat, from source: Int) -> Int {
        let movedRows = Int((translation / ReorderableListMetric.pitch).rounded())
        return min(max(source + movedRows, 0), max(items.count - 1, 0))
    }

    func resetDragState() {
        draggingItemID = nil
        dragSourceIndex = nil
        dragTranslation = 0
        dropIndex = 0
    }
}

// MARK: - Preview

#if DEBUG
private struct ReorderableListPreviewItem: Identifiable {
    let id = UUID()
    let name: String
    let address: String
}

private struct ReorderableListPreviewTrashButton: View {
    var body: some View {
        Button {
        } label: {
            Image.trash
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(Color.textTertiary)
        }
        .buttonStyle(.plain)
    }
}

// c04 · c05
#Preview("3개") {
    @Previewable @State var items: [ReorderableListPreviewItem] = [
        ReorderableListPreviewItem(name: "장소명", address: "경기도 안산시 모모로 145길 (뭐뭐동)"),
        ReorderableListPreviewItem(name: "다른 장소명", address: "서울시 마포구 어디로 12 (어디동)"),
        ReorderableListPreviewItem(name: "또 다른 장소명", address: "서울시 성동구 저기로 34 (저기동)")
    ]

    ReorderableList(
        items: items,
        // 부품은 배열을 안 고친다. 실제 순서 변경은 이렇게 부르는 쪽이 한다
        onMove: { from, to in
            items.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        },
        rowTitle: \.name,
        rowSubtitle: \.address
    ) { _ in
        ReorderableListPreviewTrashButton()
    }
    .padding(.horizontal, Spacing.s20)
}

// c04
#Preview("1개") {
    @Previewable @State var items: [ReorderableListPreviewItem] = [
        ReorderableListPreviewItem(name: "장소명", address: "경기도 안산시 모모로 145길 (뭐뭐동)")
    ]

    ReorderableList(
        items: items,
        onMove: { from, to in
            items.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        },
        rowTitle: \.name,
        rowSubtitle: \.address
    ) { _ in
        ReorderableListPreviewTrashButton()
    }
    .padding(.horizontal, Spacing.s20)
}
#endif
