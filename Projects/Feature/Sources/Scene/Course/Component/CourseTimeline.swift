import SharedDesignSystem
import SwiftUI

// MARK: - CourseStop

/// 코스에 담긴 한 곳. 화면에 그대로 찍히는 글자만 받는다.
struct CourseStop: Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let address: String
}

// MARK: - CourseLeg

/// 두 정류장 사이 이동.
///
/// 시간·거리는 이미 만들어진 글자를 받고, 무엇으로 이동하는지도 부르는 쪽이 정한다.
/// 값을 못 받은 구간은 시간을 비우고 거리 자리에 안내 문구를 받는다. 모양이 거리 글자와 같다.
/// 뷰는 수단에 맞는 아이콘과 VoiceOver 가 읽을 글자를 고른다. 분·킬로미터를 계산하지 않는다.
struct CourseLeg: Equatable {
    /// 아이콘과 길찾기 수단을 가른다. 버스·지하철·둘 다 `transit` 하나다
    enum Mode: Equatable {
        case walk
        case transit
        /// 값을 못 받은 구간. 아이콘은 발자국이고 길찾기는 대중교통으로 연다(먼 구간이라 걷기는 쓸모가 없다)
        case unavailable
    }

    let mode: Mode
    let duration: String
    let distance: String

    /// 「카카오맵으로 보기」 를 VoiceOver 가 읽는 글자. 어느 수단 길찾기가 열리는지 알린다
    var directionsAccessibilityLabel: String {
        switch mode {
        case .walk: "도보 길찾기를 카카오맵으로 보기"
        case .transit, .unavailable: "대중교통 길찾기를 카카오맵으로 보기"
        }
    }
}

// MARK: - CourseTimelineMetric

private enum CourseTimelineMetric {
    static let railWidth: CGFloat = 24
    static let legIconSize: CGFloat = 24
    static let legContentHeight: CGFloat = 28
    static let directionsArrowSize: CGFloat = 16
    /// 「카카오맵으로 보기」 를 누를 수 있는 최소 높이. 애플 HIG 최소 44
    static let directionsHitHeight: CGFloat = 44
    /// 장소명 타이포. 배지 세로 위치를 이 줄 높이에 맞추므로 한곳에서 읽는다
    static let stopNameTypography: Typography = .headline
    static let dividerHeight: CGFloat = 1
}

// MARK: - CourseTimeline

/// 코스 순서를 위에서 아래로 잇는 타임라인.
///
/// 번호 배지 사이를 빨강 점선으로 잇고, 사이마다 이동 구간을 한 줄 끼운다.
/// `legs` 는 `stops` 보다 하나 적다. 값이 없어도 구간 행은 그려서 점선이 끊기지 않게 한다.
/// 구간 행 오른쪽 끝 「카카오맵으로 보기」 를 누르면 `onLegTap` 에 구간 번호(0부터)를 넘긴다.
/// 행의 나머지 자리는 눌리지 않는다.
/// 좌우 여백은 호출부가 넣는다.
///
/// ```swift
/// CourseTimeline(stops: stops, legs: legs) { index in ... }
///     .padding(.horizontal, Spacing.s24)
/// ```
struct CourseTimeline: View {
    private let stops: [CourseStop]
    private let legs: [CourseLeg]
    private let onLegTap: (Int) -> Void

    init(
        stops: [CourseStop],
        legs: [CourseLeg],
        onLegTap: @escaping (Int) -> Void = { _ in }
    ) {
        self.stops = stops
        self.legs = legs
        self.onLegTap = onLegTap
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                stopRow(stop, number: index + 1, isFirst: index == 0, isLast: isLast(index))

                if !isLast(index) {
                    legRow(
                        leg(after: index) ?? CourseLeg(mode: .unavailable, duration: "", distance: ""),
                        index: index
                    )
                }
            }
        }
    }
}

// MARK: - Data

private extension CourseTimeline {

    func isLast(_ index: Int) -> Bool {
        index == stops.count - 1
    }

    /// 마지막 정류장 뒤에는 구간이 없다.
    func leg(after index: Int) -> CourseLeg? {
        guard !isLast(index), legs.indices.contains(index) else { return nil }
        return legs[index]
    }
}

// MARK: - Row

private extension CourseTimeline {

    func stopRow(_ stop: CourseStop, number: Int, isFirst: Bool, isLast: Bool) -> some View {
        row {
            VStack(spacing: 0) {
                if !isFirst {
                    connector
                        .frame(height: Spacing.s24)
                        .padding(.top, -Spacing.s24)
                }
                numberBadge(number)
                if !isLast {
                    connector
                }
            }
            // 내용 쪽 위 여백과 같아야 배지 원 중심이 이름줄 가운데에 온다
            .padding(.top, Spacing.s24)
        } content: {
            VStack(alignment: .leading, spacing: Spacing.s4) {
                HStack(spacing: Spacing.s8) {
                    Text(stop.name)
                        .typography(CourseTimelineMetric.stopNameTypography)
                        .foregroundStyle(Color.textPrimary)

                    Text(stop.category)
                        .typography(.body2M)
                        .foregroundStyle(Color.textTertiary)
                }

                Text(stop.address)
                    .typography(.caption1R)
                    .foregroundStyle(Color.textTertiary)
            }
            // 시안 계산은 20 이지만 SwiftUI 는 한 줄짜리 Text 에 행간을 얹지 않는다.
            // 이름줄이 27 이 아니라 21.6, 주소가 18.2 가 아니라 15.7 로 잡혀 행이 8 짧아진다.
            // 24 로 올려 행 높이(90.3 ≈ 시안 89)와 배지 세로 위치를 시안에 맞춘다.
            .padding(.vertical, Spacing.s24)
        }
    }

    func legRow(_ leg: CourseLeg, index: Int) -> some View {
        row {
            // 수단 아이콘이 점선을 끊고 그 자리에 들어간다
            VStack(spacing: 0) {
                connector
                legIcon(leg.mode)
                connector
            }
        } content: {
            // 시안은 시간·거리를 왼쪽, 링크를 오른쪽 끝에 두고 세로 가운데로 맞춘다.
            // 링크는 자연 폭을 지키고, 남는 폭은 시간·거리 쪽이 받아 링크 앞 빈 공간이 된다
            HStack(spacing: Spacing.s8) {
                legText(leg)
                    .frame(maxWidth: .infinity, alignment: .leading)

                directionsLink(leg, index: index)
            }
            // 시안의 두 겹 여백: 링크 줄 위아래 4, 글자 칸 위아래 16. 행 높이 16+4+28+4+16 = 68
            .padding(.vertical, Spacing.s4 + Spacing.s16)
        }
    }

    /// 시안은 둘이 한 줄이다. 글자는 줄이지 않는다.
    /// 링크 앞 폭에 한 줄로 안 들어가면 거리를 다음 줄로 내린다.
    /// 값을 못 받은 구간은 안내 문구 한 덩이만 보인다
    @ViewBuilder
    func legText(_ leg: CourseLeg) -> some View {
        if leg.mode == .unavailable {
            // 안내 문구는 링크 앞 폭이 모자라면 줄을 바꾼다. 링크 쪽으로 넘치지 않는다
            Text(leg.distance)
                .typography(.caption1R)
                .foregroundStyle(Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.s8) {
                    legDuration(leg)
                    legDistance(leg)
                }
                VStack(alignment: .leading, spacing: 0) {
                    legDuration(leg)
                    legDistance(leg)
                }
            }
        }
    }

    func legDuration(_ leg: CourseLeg) -> some View {
        Text(leg.duration)
            .typography(.body2M)
            .foregroundStyle(Color.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    func legDistance(_ leg: CourseLeg) -> some View {
        Text(leg.distance)
            .typography(.caption1R)
            .foregroundStyle(Color.textTertiary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// 구간에서 눌리는 곳은 여기뿐이다. 값을 못 받은 행에도 보인다
    func directionsLink(_ leg: CourseLeg, index: Int) -> some View {
        Button {
            onLegTap(index)
        } label: {
            HStack(spacing: Spacing.s4) {
                Text("카카오맵으로 보기")
                    .typography(.body2SB)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)

                Image.chevronRight
                    .renderingMode(.template)
                    .resizable()
                    .frame(
                        width: CourseTimelineMetric.directionsArrowSize,
                        height: CourseTimelineMetric.directionsArrowSize
                    )
            }
            .foregroundStyle(Color.brandPrimary)
            .frame(minHeight: CourseTimelineMetric.legContentHeight)
            // 보이는 칸은 28 그대로 두고 누르는 모양만 사방 8 씩 넓혀 44 로 만든다.
            // 모양은 레이아웃 크기에 안 들어가 행 높이가 그대로고, 넓힌 8 은 위아래 여백 20 안에 머문다
            .contentShape(
                Rectangle().inset(
                    by: -(CourseTimelineMetric.directionsHitHeight - CourseTimelineMetric.legContentHeight) / 2
                )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(leg.directionsAccessibilityLabel)
    }

    /// 왼쪽은 점선 레일, 오른쪽은 내용. 구분선은 내용 쪽에만 깔린다.
    ///
    /// 행 높이는 내용이 정한다. 레일은 세로로 무한히 늘어나려 하므로 형제로 두면
    /// 행 높이를 화면 높이까지 밀어올린다. 그래서 왼쪽은 여백으로 자리만 비우고
    /// 레일은 `overlay` 로 얹는다. `overlay` 는 부모 크기에 영향을 주지 않고
    /// 부모(= 내용 + 구분선) 높이를 그대로 받으므로, 점선이 행 끝까지 이어진다.
    func row<Rail: View, Content: View>(
        @ViewBuilder rail: () -> Rail,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // 시안의 글자 칸 안쪽 여백. 구분선은 이 여백 밖이라 시작 x 가 그대로다
            content()
                .padding(.horizontal, Spacing.s4)
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.borderWeak)
                .frame(height: CourseTimelineMetric.dividerHeight)
        }
        .padding(.leading, CourseTimelineMetric.railWidth + Spacing.s12)
        .overlay(alignment: .topLeading) {
            rail()
                .frame(width: CourseTimelineMetric.railWidth)
        }
    }
}

// MARK: - Rail

private extension CourseTimeline {

    /// 번호 배지. 원 중심을 장소명 첫 줄의 세로 중심에 맞춘다.
    ///
    /// 배지 프레임은 24, 원은 20 이라 위에서 세면 어긋난다.
    /// 안 보이는 같은 타이포 글자로 이름 한 줄 높이를 잡고 그 가운데에 배지를 얹으면,
    /// 타이포가 바뀌어도 중심이 따라온다.
    func numberBadge(_ number: Int) -> some View {
        Text(verbatim: "0")
            .typography(CourseTimelineMetric.stopNameTypography)
            .hidden()
            .overlay {
                PlaceNumberBadge(state: .number(number))
            }
    }

    /// 레일에 남는 높이를 다 채운다. 그래야 배지와 배지가 끊김 없이 이어진다.
    ///
    /// 이 탐욕이 행 높이로 번지지 않는 것은 레일이 `overlay` 안에 있기 때문이다.
    var connector: some View {
        DottedVerticalLine(color: .brandPrimary)
            .frame(maxHeight: .infinity)
    }

    func legIcon(_ mode: CourseLeg.Mode) -> some View {
        legImage(mode)
            .renderingMode(.template)
            .resizable()
            .frame(
                width: CourseTimelineMetric.legIconSize,
                height: CourseTimelineMetric.legIconSize
            )
            .foregroundStyle(Color.textTertiary)
    }

    func legImage(_ mode: CourseLeg.Mode) -> Image {
        switch mode {
        case .walk, .unavailable: Image.walk
        case .transit: Image.bus
        }
    }
}

// MARK: - Preview

#if DEBUG
private extension CourseStop {
    static func preview(_ index: Int) -> CourseStop {
        CourseStop(
            id: "stop-\(index)",
            name: "장소명",
            category: "카테고리",
            address: "경기도 안산시 모모로 145길 (뭐뭐동)"
        )
    }
}

private struct CourseTimelinePreviewHost: View {
    let stops: [CourseStop]
    let legs: [CourseLeg]

    var body: some View {
        CourseTimeline(stops: stops, legs: legs)
            .padding(.horizontal, Spacing.s24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.bgDefault)
    }
}

// 4992:25865 — 3곳, 첫 구간은 대중교통, 둘째는 긴 도보(배지 없음)
#Preview("3곳 · 대중교통 섞임") {
    CourseTimelinePreviewHost(
        stops: [.preview(0), .preview(1), .preview(2)],
        legs: [
            CourseLeg(mode: .transit, duration: "대중교통 20분", distance: "1.5 km"),
            CourseLeg(mode: .walk, duration: "도보 1시간 20분", distance: "5.3 km")
        ]
    )
}

// c02 — 도보만 있는 짧은 코스
#Preview("2곳 · 도보") {
    CourseTimelinePreviewHost(
        stops: [.preview(0), .preview(1)],
        legs: [CourseLeg(mode: .walk, duration: "도보 20분", distance: "1.5 km")]
    )
}

// c01 — 한 곳뿐이면 점선도 구간도 안 나온다
#Preview("1곳") {
    CourseTimelinePreviewHost(
        stops: [.preview(0)],
        legs: []
    )
}

// 시간·거리가 가장 길 때. 링크 앞 폭에 한 줄로 안 들어가면 거리가 다음 줄로 내려간다.
// 링크와 겹치지 않는지 눈으로 보려고 둔다
#Preview("구간 폭 한계") {
    CourseTimelinePreviewHost(
        stops: [.preview(0), .preview(1)],
        legs: [CourseLeg(mode: .transit, duration: "대중교통 10시간 20분", distance: "123.4 km")]
    )
}
#endif
