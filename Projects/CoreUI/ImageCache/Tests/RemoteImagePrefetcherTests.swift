import CoreImageCache
import Foundation
import ThirdPartyUI
import XCTest

final class RemoteImagePrefetcherTests: XCTestCase {
    private static let urlStrings = [
        "https://dulpick.test/prefetch-1.png",
        "https://dulpick.test/prefetch-2.png",
        "https://dulpick.test/prefetch-3.png"
    ]

    /// 신호가 오지 않을 때만 걸리는 제한 시간. 통과하는 실행에서는 기다리지 않는다
    private static let signalTimeout: TimeInterval = 3

    func test_미리받기_캐시적재() async throws {
        let urls = try Self.makeURLs()
        let stored = XCTestExpectation(description: "미리 받은 이미지가 캐시에 들어간다")
        stored.expectedFulfillmentCount = urls.count
        let pipeline = Self.makePipeline(
            dataLoader: StubDataLoader(data: Self.onePixelPNGData),
            imageCache: NotifyingImageCache { stored.fulfill() }
        )
        let prefetcher = RemoteImagePrefetcher(pipeline: pipeline)

        prefetcher.start(urls)
        await fulfillment(of: [stored], timeout: Self.signalTimeout)

        for url in urls {
            XCTAssertNotNil(pipeline.cache[ImageRequest(url: url)], "미리 받은 URL 3개가 모두 캐시에 있어야 한다")
        }

        prefetcher.stopAll()
    }

    func test_전체중단_요청취소() async throws {
        let urls = try Self.makeURLs()
        let requested = XCTestExpectation(description: "미리 받기 요청이 로더에 닿는다")
        let cancelled = XCTestExpectation(description: "중단하면 받던 요청이 취소된다")
        // 동시에 받는 수만큼 신호가 여러 번 올 수 있다
        requested.assertForOverFulfill = false
        cancelled.assertForOverFulfill = false
        // 중단이 먼저 닿도록 응답을 붙잡아 둔다. 바로 응답하면 시작하자마자 끝나 취소를 볼 수 없다
        let pipeline = Self.makePipeline(
            dataLoader: StubDataLoader(
                data: Self.onePixelPNGData,
                responding: .never,
                onRequest: { requested.fulfill() },
                onCancel: { cancelled.fulfill() }
            ),
            imageCache: ImageCache()
        )
        let prefetcher = RemoteImagePrefetcher(pipeline: pipeline)

        prefetcher.start(urls)
        // 요청이 로더에 닿은 뒤에 중단한다. 닿기 전에 중단하면 취소할 요청이 없다
        await fulfillment(of: [requested], timeout: Self.signalTimeout)
        prefetcher.stopAll()
        await fulfillment(of: [cancelled], timeout: Self.signalTimeout)

        // 중단이 고장 나면 위의 취소 신호가 오지 않아 실패한다. 아래는 취소된 요청이 캐시에 남지 않는 것을 본다
        for url in urls {
            XCTAssertNil(pipeline.cache[ImageRequest(url: url)], "취소했으면 캐시에 남지 않아야 한다")
        }
    }
}

// MARK: - Helper

private extension RemoteImagePrefetcherTests {
    static func makeURLs() throws -> [URL] {
        try urlStrings.map { string in
            try XCTUnwrap(URL(string: string))
        }
    }

    static func makePipeline(dataLoader: StubDataLoader, imageCache: any ImageCaching) -> ImagePipeline {
        var configuration = ImagePipeline.Configuration(dataLoader: dataLoader)
        configuration.imageCache = imageCache
        configuration.dataCache = nil
        // 지연 없이 결과가 나오게 한다. 테스트가 파이프라인 내부 타이밍에 안 흔들리도록
        configuration.isRateLimiterEnabled = false

        return ImagePipeline(configuration: configuration)
    }

    /// 1×1 PNG. 파일 에셋 없이 코드 안에 둔다
    static let onePixelPNGData: Data = {
        let base64 = """
        iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmM\
        IQAAAABJRU5ErkJggg==
        """
        return Data(base64Encoded: base64) ?? Data()
    }()
}
