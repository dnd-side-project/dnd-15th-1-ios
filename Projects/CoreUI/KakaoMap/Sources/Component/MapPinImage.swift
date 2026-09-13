import SwiftUI
import UIKit

/// 지도 핀 그림을 만드는 도구.
///
/// 마커가 무엇을 뜻하는지는 모른다. 화면 층이 이것으로 종류별 그림을 만든다
public enum MapPinImage {
    /// SDK 에 넘기는 그림의 배율. 포인트를 픽셀로 바꿀 때도 쓴다
    public static let scale: CGFloat = 2

    /// 흰 테를 두른 색 원.
    ///
    /// 테 두께는 3 이고 그림 크기는 `diameter + 6` 이 된다
    public static func circle(diameter: CGFloat, fill: UIColor, text: String? = nil) -> UIImage {
        let ringWidth: CGFloat = 3
        let size = CGSize(width: diameter + ringWidth * 2, height: diameter + ringWidth * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale

        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let outer = CGRect(origin: .zero, size: size)
            UIColor.white.setFill()
            context.cgContext.fillEllipse(in: outer)

            fill.setFill()
            context.cgContext.fillEllipse(in: outer.insetBy(dx: ringWidth, dy: ringWidth))

            guard let text else { return }

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: diameter * 0.5, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let bounds = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(
                    x: outer.midX - bounds.width / 2,
                    y: outer.midY - bounds.height / 2
                ),
                withAttributes: attributes
            )
        }
    }

    /// SwiftUI 부품을 지도가 받는 `UIImage` 로 굽는다.
    ///
    /// 그림자가 달린 부품은 프레임 밖으로 잉크가 번진다. `ImageRenderer` 는
    /// 프레임까지만 그리므로 `padding` 만큼 여백을 둘러 잘리지 않게 한다
    @MainActor
    public static func rendered(_ view: some View, padding: CGFloat) -> UIImage {
        let renderer = ImageRenderer(content: view.padding(padding))
        renderer.scale = scale
        return renderer.uiImage ?? UIImage()
    }

    /// 그림을 정사각형 크기에 맞춘다
    public static func resized(_ image: UIImage, to side: CGFloat) -> UIImage {
        let size = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 포인트를 픽셀로 바꾼다. SDK 가 픽셀을 받는 자리에 쓴다
    static func pixels(_ points: UInt) -> UInt {
        UInt(CGFloat(points) * scale)
    }

    static func pixels(_ points: CGFloat) -> Float {
        Float(points * scale)
    }
}
