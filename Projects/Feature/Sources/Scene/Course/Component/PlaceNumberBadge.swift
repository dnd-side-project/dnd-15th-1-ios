import SharedDesignSystem
import SwiftUI

// MARK: - PlaceSelectionState

/// 코스에 담을 장소를 고른 상태. 고르면 담긴 순서가 번호로 붙는다.
public enum PlaceSelectionState: Equatable {
    case unselected
    case number(Int)
}

// MARK: - PlaceNumberBadgeMetric

private enum PlaceNumberBadgeMetric {
    /// 바깥 프레임. `PlaceListRow` 우측 슬롯과 같은 24 × 24 다.
    static let frameSize: CGFloat = 24
    /// 실제로 보이는 원. 시안 `b06` 실측 20.
    static let circleSize: CGFloat = 20
    static let borderWidth: CGFloat = 1
}

// MARK: - PlaceNumberBadge

/// 리스트 행 우측에 붙는 번호 배지. 안 고른 빈 원과 순번이 든 채운 원 두 모습이다.
///
/// 크기는 고정이다. 바깥 24 × 24 프레임 가운데에 20 × 20 원이 놓인다.
/// 프레임이 원보다 큰 이유는 `PlaceListRow` 의 우측 슬롯(24 × 24)과 손가락이 닿는 넓이를 맞추기 위해서다.
///
/// 지도 위 마커는 이 부품이 아니다. `MapPlacePin` 을 쓴다.
///
/// ```swift
/// PlaceListRow(icon: .categoryFood, name: name, address: address) {
///     PlaceNumberBadge(state: .number(1))
/// }
/// ```
public struct PlaceNumberBadge: View {
    private let state: PlaceSelectionState

    public init(state: PlaceSelectionState) {
        self.state = state
    }

    public var body: some View {
        ZStack {
            switch state {
            case .unselected:
                Circle()
                    .strokeBorder(Color.borderDefault, lineWidth: PlaceNumberBadgeMetric.borderWidth)

            case let .number(number):
                Circle()
                    .fill(Color.brandPrimary)

                // 지름 20 원에 넣는 숫자. 시안 실측 글자 높이 9 → 약 12.5pt 라 13pt 토큰이 가장 가깝다
                Text("\(number)")
                    .typography(.caption1M)
                    .foregroundStyle(Color.textInverse)
            }
        }
        .frame(
            width: PlaceNumberBadgeMetric.circleSize,
            height: PlaceNumberBadgeMetric.circleSize
        )
        .frame(
            width: PlaceNumberBadgeMetric.frameSize,
            height: PlaceNumberBadgeMetric.frameSize
        )
    }
}

// MARK: - Preview

// b04 · b06 — 안 고른 원과 순번이 붙은 원
#Preview("번호 배지") {
    HStack(spacing: Spacing.s16) {
        PlaceNumberBadge(state: .unselected)
        PlaceNumberBadge(state: .number(1))
        PlaceNumberBadge(state: .number(2))
        PlaceNumberBadge(state: .number(3))
        PlaceNumberBadge(state: .number(12))
    }
    .padding(Spacing.s24)
}

// 24 프레임 안에 20 원이 가운데로 놓이는지 본다. 회색이 프레임, 원은 그 안쪽이다
#Preview("24 프레임 · 20 원") {
    HStack(spacing: Spacing.s16) {
        PlaceNumberBadge(state: .unselected)
            .background(Color.gray200)

        PlaceNumberBadge(state: .number(1))
            .background(Color.gray200)

        PlaceNumberBadge(state: .number(12))
            .background(Color.gray200)
    }
    .padding(Spacing.s24)
}

// b06 — 고른 행의 연분홍 배경 위
#Preview("연분홍 배경 위") {
    HStack(spacing: Spacing.s16) {
        PlaceNumberBadge(state: .number(1))
        PlaceNumberBadge(state: .number(2))
        PlaceNumberBadge(state: .unselected)
    }
    .padding(Spacing.s24)
    .frame(maxWidth: .infinity)
    .background(Color.brandSurface)
}
