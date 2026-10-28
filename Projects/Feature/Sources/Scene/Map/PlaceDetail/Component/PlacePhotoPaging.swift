import Foundation

/// 사진 뷰어 아래 점 한 칸
struct PlacePhotoDot: Equatable, Sendable {
    /// 이 점이 가리키는 사진 순번
    let index: Int
    let isCurrent: Bool
    /// 창 밖에 사진이 더 남은 쪽 끝 점. 작게 그린다
    let isSmall: Bool
}

/// 사진 뷰어 양옆 화살표를 보일지
struct PlacePhotoArrows: Equatable, Sendable {
    let showsPrevious: Bool
    let showsNext: Bool
}

/// 사진 뷰어의 점 줄과 화살표 계산. 시안의 점 5개 모양을 지키려고 5칸 창으로 그린다
enum PlacePhotoPaging {
    /// 점 줄이 한 번에 그리는 칸 수
    static let windowSize = 5

    /// 5장 이하면 다 그린다. 넘으면 지금 사진을 가운데 둔 5칸만 그리고, 창 밖에 사진이 남은 쪽 끝 점을 작게 한다.
    /// 사진이 1장 이하면 점이 없다
    static func dots(count: Int, current: Int) -> [PlacePhotoDot] {
        guard count > 1 else { return [] }
        let current = min(max(current, 0), count - 1)
        let size = min(count, windowSize)
        let start = min(max(current - windowSize / 2, 0), count - size)
        let end = start + size
        return (start..<end).map { index in
            let isLeadingEdge = index == start && start > 0
            let isTrailingEdge = index == end - 1 && end < count
            return PlacePhotoDot(
                index: index,
                isCurrent: index == current,
                isSmall: isLeadingEdge || isTrailingEdge
            )
        }
    }

    /// 첫 사진에서는 오른쪽만, 마지막에서는 왼쪽만, 가운데서는 양쪽. 1장 이하면 없다
    static func arrows(count: Int, current: Int) -> PlacePhotoArrows {
        guard count > 1 else { return PlacePhotoArrows(showsPrevious: false, showsNext: false) }
        let current = min(max(current, 0), count - 1)
        return PlacePhotoArrows(showsPrevious: current > 0, showsNext: current < count - 1)
    }
}
