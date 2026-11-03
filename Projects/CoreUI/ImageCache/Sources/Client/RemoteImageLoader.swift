import Foundation
import ThirdPartyUI
import UIKit

/// 원본 해상도 이미지 받기. 확대해 볼 사진처럼 칸 크기로 줄이면 흐려지는 곳에 쓴다.
/// 칸 크기 요청(`RemoteImageRequest`)과 같은 파이프라인을 써서 받아 둔 원본 데이터를 다시 받지 않는다
public enum RemoteImageLoader {
    /// - Parameters:
    ///   - url: 받아올 이미지 주소
    ///   - pipeline: 받기에 쓸 파이프라인. 기본값은 `ImageCacheBootstrap.run` 이 꽂아 둔 전역 파이프라인이다
    /// - Returns: 줄이지 않고 디코드한 이미지
    public static func originalImage(
        url: URL,
        pipeline: ImagePipeline = .shared
    ) async throws -> UIImage {
        try await pipeline.image(for: ImageRequest(url: url))
    }
}
