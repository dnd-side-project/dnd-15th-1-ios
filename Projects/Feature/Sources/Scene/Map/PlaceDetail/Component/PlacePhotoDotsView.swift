import SharedDesignSystem
import SwiftUI
import UIKit

/// 사진 뷰어 아래 점 줄. `PlacePhotoPaging.dots` 가 고른 칸만 그리고, 작은 점은 작게 그린다
final class PlacePhotoDotsView: UIView {
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Spacing.s4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    /// - Parameter dots: 그릴 점. 비면 점 줄을 숨긴다
    func update(dots: [PlacePhotoDot]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for dot in dots {
            stack.addArrangedSubview(makeDot(dot))
        }
        isHidden = dots.isEmpty
    }
}

private extension PlacePhotoDotsView {
    func makeDot(_ dot: PlacePhotoDot) -> UIView {
        // 시안: 지금 사진은 20x4 막대(gray300), 나머지는 4 점(gray700)
        let height = dot.isSmall ? PlacePhotoDotsMetric.smallSize : PlacePhotoDotsMetric.size
        let width = dot.isCurrent ? PlacePhotoDotsMetric.currentWidth : height
        let view = UIView()
        view.backgroundColor = UIColor(dot.isCurrent ? Color.gray300 : Color.gray700)
        view.layer.cornerRadius = height / 2
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: width),
            view.heightAnchor.constraint(equalToConstant: height),
        ])
        return view
    }
}

private enum PlacePhotoDotsMetric {
    static let size: CGFloat = 4
    static let currentWidth: CGFloat = 20
    /// 시안에 없는 값. 창 밖에 사진이 남은 쪽 끝 점(정한 것 9)을 4 점보다 작게 보이려고 둔다
    static let smallSize: CGFloat = 2
}
