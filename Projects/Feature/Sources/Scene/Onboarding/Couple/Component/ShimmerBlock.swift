import SharedDesignSystem
import SwiftUI

// 로딩 자리표시자. gray50 바탕 위로 밝은 띠를 좌 → 우로 흘린다. 새 에셋 없이 그라데이션만 쓴다
struct ShimmerBlock: View {
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray50)
            .frame(width: width, height: height)
            .overlay {
                if !reduceMotion {
                    band
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onAppear(perform: startAnimation)
    }

    private var band: some View {
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
    ShimmerBlock(width: 160, height: 48, cornerRadius: 8)
}

#Preview("넓은 블록") {
    ShimmerBlock(width: 280, height: 56, cornerRadius: 12)
}
#endif
