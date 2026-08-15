import SwiftUI

/// 로딩 placeholder. 바탕색 위로 밝은 띠를 좌 → 우로 흘린다. 새 에셋 없이 그라데이션만 쓴다
/// 크기를 안 잡고 부모가 준 자리를 채운다. 호출부에서 `.frame` 으로 치수를 준다
public struct ShimmerBlock: View {
    private let cornerRadius: CGFloat
    private let baseColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: CGFloat = -1

    /// 시머 placeholder 를 만든다.
    /// - Parameters:
    ///   - cornerRadius: 모서리 반경. 기본값 `0`
    ///   - baseColor: 띠가 흐르는 바탕색. 기본값 `gray50`. 이미지 자리에는 `gray300` 을 넘긴다
    public init(cornerRadius: CGFloat = 0, baseColor: Color = .gray50) {
        self.cornerRadius = cornerRadius
        self.baseColor = baseColor
    }

    public var body: some View {
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
            .onChange(of: reduceMotion, handleReduceMotionChange)
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

    /// 동작 줄이기가 꺼지면(= 애니메이션 허용) 다시 흘린다
    private func handleReduceMotionChange(_ oldValue: Bool, _ newValue: Bool) {
        guard !newValue else { return }
        startAnimation()
    }

    private func startAnimation() {
        guard !reduceMotion else { return }
        // 다시 나타났을 때 `phase` 가 `1` 로 남아 있으면 값이 안 바뀌어 애니메이션이 안 걸린다
        // 같은 트랜잭션에 묶이면 되돌리기까지 애니메이션돼 띠가 거꾸로 지나가므로 애니메이션 밖에서 되돌린다
        phase = -1
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
