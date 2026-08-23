import CoreGraphics
import Foundation
import ThirdPartyUI

/// 칸의 정수 포인트와 화면 배율로 디코드 크기만 붙인 요청을 만든다.
/// `ImageProcessors.Resize` 는 원본을 다 푼 뒤에 줄이므로 쓰지 않는다.
public enum RemoteImageRequest {
    public static func make(url: URL, size: CGSize, scale: CGFloat) -> ImageRequest? {
        let width = floor(size.width)
        let height = floor(size.height)
        guard width >= 1, height >= 1, scale > 0 else {
            return nil
        }

        let pixelSize = CGSize(width: width * scale, height: height * scale)
        return ImageRequest(
            url: url,
            userInfo: [
                .thumbnailKey: ImageRequest.ThumbnailOptions(
                    size: pixelSize,
                    unit: .pixels,
                    contentMode: .aspectFill
                )
            ]
        )
    }
}
