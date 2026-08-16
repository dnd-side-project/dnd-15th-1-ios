import SwiftUI

// MARK: - Presentation

// 사용법: .bottomSheet(isPresented: $store.isPresented, isDismissable: false) { ... }
// 핸들은 컨테이너가 그리고 그 아래를 content 가 채운다. 하단 safe area 는 배경이 따로 덮는다
public extension View {
    func bottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        isDismissable: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        // 아래에서 올라오는 오버레이. dim 은 페이드, 시트는 이동 + 페이드
        // zIndex 를 적지 않으면 닫히는 동안 시트가 dim 밑으로 내려가 한 프레임에 어두워진다
        overlay {
            ZStack(alignment: .bottom) {
                if isPresented.wrappedValue {
                    Color.dimBackground
                        .ignoresSafeArea()
                        .onTapGesture {
                            guard isDismissable else { return }
                            isPresented.wrappedValue = false
                        }
                        .transition(.opacity)
                        .zIndex(0)

                    BottomSheetContainer(content: content)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .accessibilityAddTraits(isPresented.wrappedValue ? .isModal : [])
        }
        // 들어올 때보다 나갈 때를 짧게. 값이 바뀐 뒤의 상태로 평가된다
        // 바깥에 둬야 같은 값에 묶인 화면 쪽 변화도 시트와 같은 곡선으로 따라온다
        .animation(
            .easeOut(duration: isPresented.wrappedValue ? 0.3 : 0.22),
            value: isPresented.wrappedValue
        )
    }
}

// MARK: - Container

private struct BottomSheetContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            handle

            content()
        }
        .frame(maxWidth: .infinity)
        .background {
            // 배경만 하단 safe area 까지 늘린다. 내용은 늘어난 영역 밖에 있어 가려지지 않는다
            Color.commonWhite
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 32,
                        topTrailingRadius: 32
                    )
                )
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var handle: some View {
        Capsule()
            .fill(Color.gray100)
            .frame(width: 50, height: 6)
            .frame(height: 34)
    }
}
