import CoreGraphics

// MARK: - SheetRubberBand

/// 경계 밖으로 끌었을 때 실제로 넘어가는 양을 낸다.
///
/// 아이폰 기본 스크롤이 쓰는 식과 같다. 끌수록 점점 무거워지고 `dimension` 을 넘지 않는다.
/// 담는 층 812 기준으로 100 을 끌면 51, 300 을 끌면 137 넘어간다.
enum SheetRubberBand {

    /// 아이폰 기본값. 작을수록 더 무겁다
    static let coefficient: CGFloat = 0.55

    /// - Parameters:
    ///   - overflow: 경계를 벗어난 이동량. 부호가 방향이다
    ///   - dimension: 기준 길이. 담는 층 높이를 쓴다
    /// - Returns: 화면에 실제로 넘어갈 양. `overflow` 와 부호가 같다
    static func offset(overflow: CGFloat, dimension: CGFloat) -> CGFloat {
        guard dimension > 0, overflow != 0 else { return 0 }
        let magnitude = abs(overflow)
        let eased = (1 - 1 / (magnitude * coefficient / dimension + 1)) * dimension
        return overflow < 0 ? -eased : eased
    }
}
