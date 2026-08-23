import SwiftUI

// MARK: - Presentation

public extension View {
    func bottomSheet<Content: View>(
        isPresented: Binding<Bool>,
        isDismissable: Bool = true,
        showsHandle: Bool = true,
        onDismissed: @escaping () -> Void = {},
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        overlay {
            BottomSheetHost(
                isPresented: isPresented,
                isDismissable: isDismissable,
                showsHandle: showsHandle,
                onDismissed: onDismissed,
                content: content
            )
        }
    }
}

// MARK: - Dismiss gate

/// 부모 화면이 트리에서 빠지면 닫힘 완료가 `onDismissed` 를 부르지 않게 한다
struct BottomSheetDismissGate: Equatable, Sendable {
    private(set) var generation = 0

    @discardableResult
    mutating func bump() -> Int {
        generation += 1
        return generation
    }

    func shouldDeliver(started: Int) -> Bool {
        started == generation
    }
}

// MARK: - Host

private struct BottomSheetHost<Content: View>: View {
    @Binding var isPresented: Bool
    let isDismissable: Bool
    let showsHandle: Bool
    let onDismissed: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var isMounted = false
    @State private var isOpen = false
    @State private var dismissGate = BottomSheetDismissGate()

    var body: some View {
        ZStack(alignment: .bottom) {
            if isMounted {
                Color.dimBackground
                    .opacity(isOpen ? 1 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(isOpen)
                    .onTapGesture {
                        guard isDismissable else { return }
                        isPresented = false
                    }
                    .zIndex(0)

                BottomSheetContainer(showsHandle: showsHandle, content: content)
                    .offset(y: isOpen ? 0 : UIScreen.main.bounds.height)
                    .zIndex(1)
            }
        }
        .accessibilityAddTraits(isOpen ? .isModal : [])
        .onChange(of: isPresented, initial: true) { _, presented in
            syncPresentation(presented)
        }
        .onDisappear {
            dismissGate.bump()
        }
    }

    private func syncPresentation(_ presented: Bool) {
        if presented {
            let generation = dismissGate.bump()
            if !isMounted {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    isMounted = true
                    isOpen = false
                }
                // 같은 프레임에 열면 시작 오프셋 없이 끝 자리에 붙는다
                DispatchQueue.main.async {
                    guard dismissGate.shouldDeliver(started: generation) else { return }
                    withAnimation(Motion.sheetSpring) {
                        isOpen = true
                    }
                }
            } else {
                withAnimation(Motion.sheetSpring) {
                    isOpen = true
                }
            }
            return
        }
        guard isMounted else { return }
        let generation = dismissGate.bump()
        withAnimation(Motion.sheetSpring, completionCriteria: .removed) {
            isOpen = false
        } completion: {
            guard dismissGate.shouldDeliver(started: generation) else { return }
            isMounted = false
            onDismissed()
        }
    }
}

// MARK: - Container

private struct BottomSheetContainer<Content: View>: View {
    let showsHandle: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            if showsHandle { handle }

            content()
        }
        .frame(maxWidth: .infinity)
        .background {
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
            .padding(.top, 14)
            .padding(.bottom, 13)
    }
}
