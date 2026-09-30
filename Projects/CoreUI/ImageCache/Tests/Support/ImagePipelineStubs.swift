import Foundation
import ThirdPartyUI

/// 네트워크 없이 같은 데이터를 돌려주는 가짜 로더
final class StubDataLoader: DataLoading {
    enum Responding: Sendable {
        /// 요청을 받은 자리에서 바로 데이터를 돌려준다
        case immediately
        /// 응답하지 않고 붙잡아 둔다. 중단이 응답보다 먼저 닿는 상황을 만든다
        case never
    }

    private let data: Data
    private let responding: Responding
    private let onRequest: @Sendable () -> Void
    private let onCancel: @Sendable () -> Void

    /// - Parameters:
    ///   - data: 모든 요청에 돌려줄 이미지 데이터
    ///   - responding: 응답하는 방식. 기본값은 바로 응답이다
    ///   - onRequest: 요청이 로더에 닿을 때마다 부른다
    ///   - onCancel: 로더가 받은 요청이 취소될 때마다 부른다
    init(
        data: Data,
        responding: Responding = .immediately,
        onRequest: @escaping @Sendable () -> Void = {},
        onCancel: @escaping @Sendable () -> Void = {}
    ) {
        self.data = data
        self.responding = responding
        self.onRequest = onRequest
        self.onCancel = onCancel
    }

    func loadData(
        with request: URLRequest,
        didReceiveData: @escaping @Sendable (Data, URLResponse) -> Void,
        completion: @escaping @Sendable (Error?) -> Void
    ) -> any Cancellable {
        let task = StubDataTask(onCancel: onCancel)

        guard let url = request.url else {
            completion(URLError(.badURL))
            return task
        }

        onRequest()

        guard responding == .immediately else {
            return task
        }

        let response = URLResponse(
            url: url,
            mimeType: "image/png",
            expectedContentLength: data.count,
            textEncodingName: nil
        )
        didReceiveData(data, response)
        completion(nil)

        return task
    }
}

final class StubDataTask: Cancellable {
    private let onCancel: @Sendable () -> Void

    init(onCancel: @escaping @Sendable () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

/// 이미지가 저장될 때마다 알려 주는 메모리 캐시. 저장과 조회는 `ImageCache` 가 그대로 한다
final class NotifyingImageCache: ImageCaching {
    private let cache = ImageCache()
    private let onStore: @Sendable () -> Void

    /// - Parameter onStore: 이미지가 캐시에 들어간 직후에 부른다
    init(onStore: @escaping @Sendable () -> Void) {
        self.onStore = onStore
    }

    subscript(key: ImageCacheKey) -> ImageContainer? {
        get { cache[key] }
        set {
            cache[key] = newValue
            if newValue != nil {
                onStore()
            }
        }
    }

    func removeAll() {
        cache.removeAll()
    }
}
