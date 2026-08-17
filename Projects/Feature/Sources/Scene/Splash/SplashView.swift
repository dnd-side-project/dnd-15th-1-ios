import SharedDesignSystem
import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Image.splashBackground
                .resizable()
                .scaledToFill()

            Image.splashBundle
                .resizable()
                .scaledToFit()
                .frame(width: SplashMetric.bundleWidth, height: SplashMetric.bundleHeight)
                .offset(y: -SplashMetric.verticalOffset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

private enum SplashMetric {
    /// 로고와 문구를 한 장으로 내보낸 그림이다. 런치 화면이 폰트를 못 써서 스토리보드와 같은 그림을 쓴다
    static let bundleWidth: CGFloat = 201
    static let bundleHeight: CGFloat = 164
    /// 시안(393 × 852)에서 로고+문구 묶음의 중심이 화면 중심보다 36 위다
    static let verticalOffset: CGFloat = 36
}

#Preview {
    SplashView()
}
