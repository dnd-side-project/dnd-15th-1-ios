import Foundation
import ThirdPartyUI

/// 이미지 미리 받기. 인스턴스 하나가 동시 다운로드 수를 제한하므로 화면당 하나만 두고 공유한다
public final class RemoteImagePrefetcher {
    private let prefetcher: ImagePrefetcher

    public init(pipeline: ImagePipeline = .shared) {
        prefetcher = ImagePrefetcher(pipeline: pipeline)
    }

    public func start(_ urls: [URL]) {
        prefetcher.startPrefetching(with: urls)
    }

    public func stop(_ urls: [URL]) {
        prefetcher.stopPrefetching(with: urls)
    }

    public func stopAll() {
        prefetcher.stopPrefetching()
    }
}
