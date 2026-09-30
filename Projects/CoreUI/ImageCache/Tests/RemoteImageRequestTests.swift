import CoreImageCache
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

    func test_소수_포인트는_내리고_배율로_픽셀을_붙인다() async throws {
        let url = try XCTUnwrap(URL(string: "https://dulpick.test/photo.png"))
        let png = Self.makePNGData(width: 800, height: 800)
        let pipeline = Self.makePipeline(data: png)
        let request = try XCTUnwrap(
            RemoteImageRequest.make(
                url: url,
                size: CGSize(width: 88.9, height: 88.9),
                scale: 3
            )
        )

        let image = try await pipeline.image(for: request)
        let pixels = image.size.width * image.scale

        // 88 포인트에 배율 3 을 곱한 값이다. 소수를 내리지 않으면 88.9 × 3 이라 267 픽셀이 된다
        XCTAssertEqual(pixels, 264, accuracy: 1)
        XCTAssertTrue(request.processors.isEmpty)
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

        // 같은 파이프라인에서 같은 주소를 두 크기로 차례로 받는다.
        // 칸 크기가 캐시 키에 안 들어가면 둘째가 첫째의 비트맵으로 나온다
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
            dataLoader: StubDataLoader(data: data)
        )
        configuration.imageCache = ImageCache()
        configuration.dataCache = nil
        configuration.isRateLimiterEnabled = false
        return ImagePipeline(configuration: configuration)
    }
}
