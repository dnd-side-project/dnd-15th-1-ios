import SharedDesignSystem
import SwiftUI

/// 로딩 자리표시자. 바탕색 위로 밝은 띠를 좌 → 우로 흘린다. 새 에셋 없이 그라데이션만 쓴다
/// 크기를 안 잡고 부모가 준 자리를 채운다. 호출부에서 `.frame` 으로 치수를 준다
struct ShimmerBlock: View {
    var cornerRadius: CGFloat = 0
    var baseColor: Color = .gray50

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(baseColor)
            .overlay {
                if !reduceMotion {
                    // 부모가 준 자리를 그대로 쓰므로 띠 너비와 이동 거리를 자기 폭에서 계산한다
                    GeometryReader { proxy in
                        band(width: proxy.size.width)
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear(perform: startAnimation)
    }

    private func band(width: CGFloat) -> some View {
        LinearGradient(
            colors: [
                Color.commonWhite.opacity(0),
                Color.commonWhite.opacity(0.9),
                Color.commonWhite.opacity(0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width * 0.6)
        .offset(x: phase * width * 1.3)
        .allowsHitTesting(false)
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }
}

#if DEBUG
#Preview("코드 자리") {
    ShimmerBlock(cornerRadius: 8)
        .frame(width: 160, height: 48)
}

#Preview("넓은 블록") {
    ShimmerBlock(cornerRadius: 12)
        .frame(width: 280, height: 56)
}

#Preview("이미지 자리 · gray300") {
    ShimmerBlock(cornerRadius: 12, baseColor: .gray300)
        .frame(width: 280, height: 160)
}
#endif
