import SharedDesignSystem
import SwiftUI
import ThirdPartyUI

/// 원격 이미지 한 장. 로딩은 시머, 실패와 URL 없음은 같은 자리표시자로 보인다
public struct RemoteImage: View {
    private static let fadeDuration: TimeInterval = 0.25
    private static let placeholderIconSize: CGFloat = 24

    private let url: URL?
    private let cornerRadius: CGFloat

    /// 원격 이미지를 표시한다.
    /// - Parameters:
    ///   - url: 받아올 이미지 주소. `nil` 이면 실패와 같은 자리표시가 보인다
    ///   - cornerRadius: 이미지와 자리표시에 함께 적용할 모서리 반경. 기본값 `0`
    public init(url: URL?, cornerRadius: CGFloat = 0) {
        self.url = url
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    private var content: some View {
        if let url {
            LazyImage(
                url: url,
                transaction: Transaction(animation: .easeOut(duration: Self.fadeDuration))
            ) { state in
                if let image = state.image {
                    // Color.clear 가 부모 제안 크기를 그대로 받아, 넘치는 부분을 자를 기준을 만든다
                    Color.clear
                        .overlay {
                            image.resizable().scaledToFill()
                        }
                } else if state.error != nil {
                    placeholder
                } else {
                    ShimmerBlock(baseColor: .gray300)
                }
            }
        } else {
            placeholder
        }
    }

    // 실패와 URL 없음은 사용자가 할 수 있는 행동이 같아 화면에서 나누지 않는다
    private var placeholder: some View {
        Color.gray300.overlay {
            // 에셋에 색이 박혀 있어 foregroundStyle 로 물들이지 않는다
            Image.error
                .resizable()
                .frame(
                    width: Self.placeholderIconSize,
                    height: Self.placeholderIconSize
                )
        }
    }
}

#if DEBUG
// 프리뷰 치수: a10 썸네일 88×88, a03 상세 사진 335×200
private enum RemoteImagePreviewSize {
    static let thumbnail = CGSize(width: 88, height: 88)
    static let detail = CGSize(width: 335, height: 200)
}

@MainActor
@ViewBuilder
private func remoteImagePreviewPair(_ url: URL?) -> some View {
    VStack(spacing: 20) {
        // a10 썸네일 88×88
        RemoteImage(url: url, cornerRadius: 8)
            .frame(
                width: RemoteImagePreviewSize.thumbnail.width,
                height: RemoteImagePreviewSize.thumbnail.height
            )

        // a03 상세 사진
        RemoteImage(url: url, cornerRadius: 12)
            .frame(
                width: RemoteImagePreviewSize.detail.width,
                height: RemoteImagePreviewSize.detail.height
            )
    }
    .padding(20)
}

#Preview("로딩") {
    // 응답이 안 오는 주소라 시머 상태로 멈춘다
    remoteImagePreviewPair(URL(string: "https://10.255.255.1/never-responds.jpg"))
}

#Preview("성공") {
    // 네트워크를 안 타게 번들 안 이미지를 file:// 로 읽는다
    remoteImagePreviewPair(RemoteImagePreviewAsset.localImageURL)
}

#Preview("실패") {
    remoteImagePreviewPair(URL(string: "https://dulpick.invalid/missing.jpg"))
}

#Preview("URL 없음") {
    remoteImagePreviewPair(nil)
}

// 프리뷰 전용. 가로로 긴 PNG 를 임시 파일로 떨궈 file:// 로 읽는다. 네트워크를 안 탄다
private enum RemoteImagePreviewAsset {
    static let localImageURL: URL? = {
        guard let data = Data(base64Encoded: widePNGBase64) else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("remote-image-preview.png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }()

    // 8×2 PNG. 좌우 색이 달라 88×88 에서 scaledToFill 이 좌우를 잘라내는 게 눈에 보인다
    private static let widePNGBase64 = """
    iVBORw0KGgoAAAANSUhEUgAAAAgAAAACCAIAAADq9gq6AAAAHElEQVR42mO4Y2QER0YBd+CI\
    QWNVFBx9OKEBRwAP5Bap+sHiIAAAAABJRU5ErkJggg==
    """
}
#endif
