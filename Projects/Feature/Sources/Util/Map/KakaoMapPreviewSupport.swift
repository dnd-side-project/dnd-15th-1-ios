#if DEBUG
import Foundation
import SharedUtils
import SwiftUI
import ThirdPartyUI

/// SwiftUI 프리뷰에서 카카오 지도 뷰를 만들어도 되는지 판단하고, 되면 SDK 를 초기화한다.
/// 제품 실행 경로의 초기화 지점은 `App/Sources/DI/AppBootstrap.swift` 하나뿐이고 그대로 둔다.
/// 프리뷰는 App 타깃을 거치지 않아 그 초기화가 없는 상태로 뜨기 때문에 이 타입이 그 공백만 메운다.
@MainActor
enum KakaoMapPreviewSupport {
    private static var isSDKInitialized = false

    /// `false` 면 지도 뷰를 만들면 안 된다. SDK 가 크래시한다(`hasResourceBundle` 참고).
    @discardableResult
    static func prepareIfPossible() -> Bool {
        KakaoMapPreviewBundleShim.activateIfNeeded()

        guard hasResourceBundle else { return false }
        guard !isSDKInitialized else { return true }

        // 프리뷰 호스트 Info.plist 에는 앱 키가 없어 AppInfo 가 nil → 심이 찾아 둔 폴백 키를 쓴다.
        guard
            let appKey = AppInfo.string(.kakaoNativeAppKey)
                ?? KakaoMapPreviewBundleShim.fallbackAppKey?.value
        else { return false }

        SDKInitializer.InitSDK(appKey: appKey)
        isSDKInitialized = true
        return true
    }

    /// SDK 는 지도 리소스 번들을 `Bundle.main` 에서만 찾는다. `KMViewContainer()` 는 생성자에서
    /// 표식 plist 를 가진 `.bundle` 을 고르는데, 못 찾으면 내부에서 `strlen(NULL)` 로 크래시한다.
    /// 되돌릴 수 있는 실패가 아니라서 호출부가 뷰 생성 자체를 막는다.
    private static var hasResourceBundle: Bool {
        Bundle.main
            .paths(forResourcesOfType: "bundle", inDirectory: nil)
            .lazy
            .compactMap(Bundle.init(path:))
            .contains { $0.path(forResource: resourceMarker, ofType: "plist") != nil }
    }

    /// 경로의 단일 원천은 심의 `markerRelativePath`. 여기서는 확장자만 떼어 쓴다.
    private static let resourceMarker =
        (KakaoMapPreviewBundleShim.markerRelativePath as NSString).deletingPathExtension
}

// MARK: - 프리뷰 래퍼

/// 지도 뷰를 만들어도 안전할 때만 만들고, 아니면 자리표시자를 그리는 프리뷰 전용 래퍼.
@MainActor
struct KakaoMapPreviewContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if KakaoMapPreviewSupport.prepareIfPossible() {
            content()
        } else {
            KakaoMapPreviewUnavailableView()
        }
    }
}

private struct KakaoMapPreviewUnavailableView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .light))

            Text("이번 프리뷰에서는 지도를 띄우지 못했습니다")
                .font(.headline)

            Text(
                """
                평소에는 프리뷰에서도 지도가 뜹니다. 프리뷰 전용 보정 코드가
                지도 리소스 번들 경로와 번들 ID 를 대신 채워 주기 때문입니다.
                이 화면은 그 보정이 이번에 실패했다는 뜻입니다.

                아래 진단에서 리소스 번들 · 앱 키 · 프리뷰 환경 중 어디서 막혔는지 볼 수 있습니다.
                지도 밖 레이아웃은 이 프리뷰로 계속 보면 되고, 지도는 시뮬레이터에서 확인하세요.
                """
            )
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            Text(KakaoMapPreviewBundleShim.diagnostics.joined(separator: "\n"))
                .font(.system(.caption2, design: .monospaced))
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.5)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
    }
}
#endif
