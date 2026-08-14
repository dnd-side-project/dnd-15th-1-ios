import Foundation
import ThirdPartyUI

/// 이미지 캐시 조립. 만료·메모리 경고·백그라운드 정리는 Nuke 가 이미 한다
public enum ImageCacheBootstrap {
    private static let memoryLimit = 100 * 1024 * 1024
    private static let diskLimit = 500 * 1024 * 1024

    @MainActor
    public static func run(namespace: String) {
        ImageCache.shared.costLimit = memoryLimit

        // withDataCache 가 URLCache 를 끄고 DataCache 를 켠다.
        // 서버가 캐시 헤더를 안 줘도 껐다 켰을 때 남아야 해서다
        let configuration = ImagePipeline.Configuration.withDataCache(
            name: "\(namespace).image",
            sizeLimit: diskLimit
        )
        ImagePipeline.shared = ImagePipeline(configuration: configuration)
    }
}
