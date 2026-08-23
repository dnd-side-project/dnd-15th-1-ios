import Feature
import Foundation
import ThirdPartyUI
import UIKit
import XCTest

final class RemoteImageRequestTests: XCTestCase {
    func test_칸이_0이면_요청을_만들지_않는다() throws {
        let url = try XCTUnwrap(URL(string: "https://dulpick.test/photo.png"))

        XCTAssertNil(
            RemoteImageRequest.make(url: url, size: .zero, scale: 2)
        )
        XCTAssertNil(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 0.9, height: 88),
                scale: 2
            )
        )
        XCTAssertNil(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 88, height: 88),
                scale: 0
            )
        )
    }

    func test_소수_포인트는_내리고_배율로_픽셀을_붙인다() throws {
        let url = try XCTUnwrap(URL(string: "https://dulpick.test/photo.png"))
        let floored = try XCTUnwrap(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 88, height: 88),
                scale: 2
            )
        )
        let fractional = try XCTUnwrap(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 88.7, height: 88.2),
                scale: 2
            )
        )

        XCTAssertEqual(
            floored.userInfo[.thumbnailKey] as? ImageRequest.ThumbnailOptions,
            fractional.userInfo[.thumbnailKey] as? ImageRequest.ThumbnailOptions
        )
        XCTAssertTrue(floored.processors.isEmpty)
    }

    func test_같은_주소_다른_칸은_요청이_둘이다() throws {
        let url = try XCTUnwrap(URL(string: "https://dulpick.test/photo.png"))
        let small = try XCTUnwrap(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 88, height: 88),
                scale: 2
            )
        )
        let large = try XCTUnwrap(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 160, height: 160),
                scale: 2
            )
        )

        XCTAssertEqual(small.url, large.url)
        XCTAssertNotEqual(
            small.userInfo[.thumbnailKey] as? ImageRequest.ThumbnailOptions,
            large.userInfo[.thumbnailKey] as? ImageRequest.ThumbnailOptions
        )
    }

    func test_작은_칸은_작은_비트맵으로_디코드한다() async throws {
        let url = try XCTUnwrap(URL(string: "https://dulpick.test/photo.png"))
        let png = Self.makePNGData(width: 800, height: 800)
        let pipeline = Self.makePipeline(data: png)
        let small = try XCTUnwrap(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 88, height: 88),
                scale: 2
            )
        )
        let large = try XCTUnwrap(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 160, height: 160),
                scale: 2
            )
        )

        let smallImage = try await pipeline.image(for: small)
        let largeImage = try await pipeline.image(for: large)
        let smallPixels = smallImage.size.width * smallImage.scale
        let largePixels = largeImage.size.width * largeImage.scale

        XCTAssertEqual(smallPixels, 176, accuracy: 1)
        XCTAssertEqual(largePixels, 320, accuracy: 1)
        XCTAssertLessThan(smallPixels, largePixels)
    }
}

// MARK: - Helper

private extension RemoteImageRequestTests {
    static func makePNGData(width: Int, height: Int) -> Data {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.pngData() ?? Data()
    }

    static func makePipeline(data: Data) -> ImagePipeline {
        var configuration = ImagePipeline.Configuration(
            dataLoader: StubDataLoader(data: data, delay: 0)
        )
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        configuration.isRateLimiterEnabled = false
        return ImagePipeline(configuration: configuration)
    }
}

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
