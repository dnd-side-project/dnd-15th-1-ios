import CoreGraphics

/// 시안 값 중 `Spacing` 토큰에 없는 것들
enum PostDetailMetric {
    /// 접힘에서 본문이 보이는 줄 수
    static let captionLineLimit = 3

    static let iconSize: CGFloat = 24
    /// 닫기 `X` 의 손가락 자리. 아이콘은 24 다
    static let closeButtonSize: CGFloat = 40
    /// 제목 위아래 바깥 간격
    static let titleVerticalSpacing: CGFloat = 5

    static let instagramIconSize: CGFloat = 16
    static let instagramIconGap: CGFloat = 4
    /// 시안 `padding: 7px 16px`
    static let instagramVerticalPadding: CGFloat = 7
    static let instagramCornerRadius: CGFloat = 8

    static let rowHeight: CGFloat = 56
    static let rowCornerRadius: CGFloat = 12
    static let skeletonRowCount = 3

    /// 넘침 판정에 쓰는 여유. 반올림 차이로 한 픽셀 어긋나는 것을 걸러낸다
    static let truncationTolerance: CGFloat = 1
}
