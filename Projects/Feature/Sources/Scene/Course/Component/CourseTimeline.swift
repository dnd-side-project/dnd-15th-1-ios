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
/// 시간·거리는 이미 만들어진 글자를 받고, 긴 구간인지도 부르는 쪽이 정한다.
/// 뷰가 분·킬로미터를 계산하거나 임계값을 판단하지 않는다.
struct CourseLeg: Equatable {
    let duration: String
    let distance: String
    let isLong: Bool
}

// MARK: - CourseTimelineMetric

private enum CourseTimelineMetric {
    static let railWidth: CGFloat = 24
    static let walkIconSize: CGFloat = 24
    static let legContentHeight: CGFloat = 28
    /// 장소명 타이포. 배지 세로 위치를 이 줄 높이에 맞추므로 한곳에서 읽는다
    static let stopNameTypography: Typography = .headline
    static let warningIconSize: CGFloat = 13
    static let warningCornerRadius: CGFloat = 6
    static let dividerHeight: CGFloat = 1
}

// MARK: - CourseTimeline

/// 코스 순서를 위에서 아래로 잇는 타임라인.
///
/// 번호 배지 사이를 빨강 점선으로 잇고, 사이마다 이동 구간을 한 줄 끼운다.
/// `legs` 는 `stops` 보다 하나 적다. 모자라면 그 구간은 그려지지 않는다.
/// 좌우 여백은 호출부가 넣는다.
///
/// ```swift
/// CourseTimeline(stops: stops, legs: legs)
///     .padding(.horizontal, Spacing.s24)
/// ```
struct CourseTimeline: View {
    private let stops: [CourseStop]
    private let legs: [CourseLeg]

    init(stops: [CourseStop], legs: [CourseLeg]) {
        self.stops = stops
        self.legs = legs
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                stopRow(stop, number: index + 1, isLast: isLast(index))

                if let leg = leg(after: index) {
                    legRow(leg)
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

    func stopRow(_ stop: CourseStop, number: Int, isLast: Bool) -> some View {
        row {
            VStack(spacing: Spacing.s4) {
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

    func legRow(_ leg: CourseLeg) -> some View {
        row {
            // 발자국 아이콘이 점선을 끊고 그 자리에 들어간다
            VStack(spacing: 0) {
                connector
                walkIcon
                connector
            }
        } content: {
            HStack(spacing: Spacing.s8) {
                Text(leg.duration)
                    .typography(.body2M)
                    .foregroundStyle(Color.textSecondary)

                Text(leg.distance)
                    .typography(.caption1R)
                    .foregroundStyle(Color.textTertiary)

                if leg.isLong {
                    longLegBadge
                }
            }
            .frame(minHeight: CourseTimelineMetric.legContentHeight)
            .padding(.vertical, Spacing.s16)
        }
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
            content()
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

    var walkIcon: some View {
        Image.walk
            .renderingMode(.template)
            .resizable()
            .frame(
                width: CourseTimelineMetric.walkIconSize,
                height: CourseTimelineMetric.walkIconSize
            )
            .foregroundStyle(Color.textTertiary)
    }
}

// MARK: - Badge

private extension CourseTimeline {

    var longLegBadge: some View {
        HStack(spacing: Spacing.s4) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: CourseTimelineMetric.warningIconSize, weight: .semibold))

            Text("이동이 긴 구간입니다")
                .typography(.caption2M)
        }
        .foregroundStyle(Color.statusError)
        .padding(.horizontal, Spacing.s8)
        .padding(.vertical, Spacing.s4)
        .background(
            RoundedRectangle(cornerRadius: CourseTimelineMetric.warningCornerRadius)
                .fill(Color.brandSurface)
        )
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

// c01 · c02 — 3곳, 가운데 구간만 이동이 길다
#Preview("3곳 · 가운데 경고") {
    CourseTimelinePreviewHost(
        stops: [.preview(0), .preview(1), .preview(2)],
        legs: [
            CourseLeg(duration: "도보 20분", distance: "1.5 km", isLong: false),
            CourseLeg(duration: "도보 1시간 20분", distance: "5.3 km", isLong: true)
        ]
    )
}

// c02 — 경고 없는 짧은 코스
#Preview("2곳 · 경고 없음") {
    CourseTimelinePreviewHost(
        stops: [.preview(0), .preview(1)],
        legs: [CourseLeg(duration: "도보 20분", distance: "1.5 km", isLong: false)]
    )
}

// c01 — 한 곳뿐이면 점선도 구간도 안 나온다
#Preview("1곳") {
    CourseTimelinePreviewHost(
        stops: [.preview(0)],
        legs: []
    )
}
#endif
