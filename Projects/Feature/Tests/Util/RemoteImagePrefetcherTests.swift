import Feature
import Foundation
import ThirdPartyUI
import XCTest

final class RemoteImagePrefetcherTests: XCTestCase {
    private static let urlStrings = [
        "https://dulpick.test/prefetch-1.png",
        "https://dulpick.test/prefetch-2.png",
        "https://dulpick.test/prefetch-3.png"
    ]

    func test_미리받기_캐시적재() async throws {
        let urls = try Self.makeURLs()
        let cache = ImageCache()
        let pipeline = Self.makePipeline(imageCache: cache)
        let prefetcher = RemoteImagePrefetcher(pipeline: pipeline)

        prefetcher.start(urls)
        let didCacheAll = await Self.waitUntilCached(urls, in: pipeline, timeout: 5)

        XCTAssertTrue(didCacheAll, "미리 받은 URL 3개가 모두 캐시에 있어야 한다")

        prefetcher.stopAll()
    }

    func test_전체중단_요청취소() async throws {
        let urls = try Self.makeURLs()
        let cache = ImageCache()
        // 중단이 먼저 닿도록 응답을 늦춘다. 지연이 없으면 시작하자마자 끝나 취소를 볼 수 없다
        let pipeline = Self.makePipeline(imageCache: cache, responseDelay: 0.5)
        let prefetcher = RemoteImagePrefetcher(pipeline: pipeline)

        prefetcher.start(urls)
        prefetcher.stopAll()

        try await Task.sleep(for: .seconds(1))

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

    static func makePipeline(imageCache: ImageCache, responseDelay: TimeInterval = 0) -> ImagePipeline {
        var configuration = ImagePipeline.Configuration(
            dataLoader: StubDataLoader(data: onePixelPNGData, delay: responseDelay)
        )
        configuration.imageCache = imageCache
        configuration.dataCache = nil
        // 지연 없이 결과가 나오게 한다. 테스트가 파이프라인 내부 타이밍에 안 흔들리도록
        configuration.isRateLimiterEnabled = false

        return ImagePipeline(configuration: configuration)
    }

    static func waitUntilCached(_ urls: [URL], in pipeline: ImagePipeline, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let isCached = urls.allSatisfy { pipeline.cache[ImageRequest(url: $0)] != nil }
            if isCached {
                return true
            }
            try? await Task.sleep(for: .milliseconds(20))
        }

        return false
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

// MARK: - Stub

private final class StubDataLoader: DataLoading, @unchecked Sendable {
    private let data: Data
    private let delay: TimeInterval

    init(data: Data, delay: TimeInterval) {
        self.data = data
        self.delay = delay
    }

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) -> any Cancellable {
        let task = StubDataTask()

        guard let url = request.url else {
            completion(URLError(.badURL))
            return task
        }

        let data = data
        let response = URLResponse(
            url: url,
            mimeType: "image/png",
            expectedContentLength: data.count,
            textEncodingName: nil
        )

        DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
            guard !task.isCancelled else { return }
            didReceiveData(data, response)
            completion(nil)
        }

        return task
    }
}

private final class StubDataTask: Cancellable, @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.withLock { cancelled }
    }

    func cancel() {
        lock.withLock { cancelled = true }
    }
}
