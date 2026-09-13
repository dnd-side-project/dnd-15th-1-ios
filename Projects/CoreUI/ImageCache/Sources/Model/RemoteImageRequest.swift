import CoreGraphics
import Foundation
import ThirdPartyUI

/// 칸의 정수 포인트와 화면 배율로 디코드 크기만 붙인 요청을 만든다.
/// `ImageProcessors.Resize` 는 원본을 다 푼 뒤에 줄이므로 쓰지 않는다.
public enum RemoteImageRequest {
    /// - Parameters:
    ///   - url: 받아올 이미지 주소
    ///   - size: 이미지가 놓일 칸 크기. 포인트 단위다
    ///   - scale: 화면 배율. 포인트를 픽셀로 바꾸는 데 쓴다
    /// - Returns: 칸의 가로나 세로가 1 포인트 미만이거나 배율이 0 이하면 `nil`
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
