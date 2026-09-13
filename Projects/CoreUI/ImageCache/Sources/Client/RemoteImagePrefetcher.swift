import Foundation
import ThirdPartyUI

/// 이미지 미리 받기. 인스턴스 하나가 동시 다운로드 수를 제한하므로 화면당 하나만 두고 공유한다
public final class RemoteImagePrefetcher {
    private let prefetcher: ImagePrefetcher

    /// - Parameter pipeline: 미리 받기가 쓸 파이프라인. 기본값은 `ImageCacheBootstrap.run` 이 꽂아 둔 전역 파이프라인이다
    public init(pipeline: ImagePipeline = .shared) {
        prefetcher = ImagePrefetcher(pipeline: pipeline)
    }

    /// 셀이 화면에 나타날 때 부른다.
    /// - Parameter urls: 미리 받을 이미지 주소
    public func start(_ urls: [URL]) {
        prefetcher.startPrefetching(with: urls)
    }

    /// 셀이 화면에서 사라질 때 부른다.
    /// - Parameter urls: 미리 받기를 멈출 이미지 주소
    public func stop(_ urls: [URL]) {
        prefetcher.stopPrefetching(with: urls)
    }

    /// 진행 중인 미리 받기를 전부 멈춘다.
    public func stopAll() {
        prefetcher.stopPrefetching()
    }
}
