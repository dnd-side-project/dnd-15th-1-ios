import CoreImageCache
import Foundation
import ThirdPartyUI
import UIKit
import XCTest

final class RemoteImageLoaderTests: XCTestCase {
    /// 신호가 오지 않을 때만 걸리는 제한 시간. 통과하는 실행에서는 기다리지 않는다
    private static let signalTimeout: TimeInterval = 3

    func test_원본_해상도로_받는다() async throws {
        let url = try XCTUnwrap(URL(string: "https://dulpick.test/original.png"))
        let pipeline = Self.makePipeline(
            dataLoader: StubDataLoader(data: Self.makePNGData(width: 800, height: 600))
        )

        let image = try await RemoteImageLoader.originalImage(url: url, pipeline: pipeline)

        XCTAssertEqual(image.size.width * image.scale, 800, accuracy: 1)
        XCTAssertEqual(image.size.height * image.scale, 600, accuracy: 1)
    }

    func test_칸_크기로_먼저_받았어도_원본은_원본_크기다() async throws {
        let url = try XCTUnwrap(URL(string: "https://dulpick.test/original.png"))
        let pipeline = Self.makePipeline(
            dataLoader: StubDataLoader(data: Self.makePNGData(width: 800, height: 600))
        )
        let thumbnail = try XCTUnwrap(
            RemoteImageRequest.make(url: url, size: CGSize(width: 88, height: 88), scale: 2)
        )
        _ = try await pipeline.image(for: thumbnail)

        let image = try await RemoteImageLoader.originalImage(url: url, pipeline: pipeline)

        // 칸 크기 요청이 캐시 키를 덮으면 176 픽셀 비트맵이 나온다
        XCTAssertEqual(image.size.width * image.scale, 800, accuracy: 1)
    }

    func test_두_번째는_같은_캐시에서_꺼내_다시_받지_않는다() async throws {
        let url = try XCTUnwrap(URL(string: "https://dulpick.test/original.png"))
        let requested = XCTestExpectation(description: "로더에는 한 번만 닿는다")
        requested.expectedFulfillmentCount = 1
        requested.assertForOverFulfill = true
        let pipeline = Self.makePipeline(
            dataLoader: StubDataLoader(
                data: Self.makePNGData(width: 800, height: 600),
                onRequest: { requested.fulfill() }
            )
        )

        _ = try await RemoteImageLoader.originalImage(url: url, pipeline: pipeline)
        _ = try await RemoteImageLoader.originalImage(url: url, pipeline: pipeline)

        await fulfillment(of: [requested], timeout: Self.signalTimeout)
        XCTAssertNotNil(pipeline.cache[ImageRequest(url: url)])
    }
}

// MARK: - Helper

private extension RemoteImageLoaderTests {
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

    static func makePipeline(dataLoader: StubDataLoader) -> ImagePipeline {
        var configuration = ImagePipeline.Configuration(dataLoader: dataLoader)
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        // 지연 없이 결과가 나오게 한다. 테스트가 파이프라인 내부 타이밍에 안 흔들리도록
        configuration.isRateLimiterEnabled = false
        return ImagePipeline(configuration: configuration)
    }
}
