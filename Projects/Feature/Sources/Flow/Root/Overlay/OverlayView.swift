import SwiftUI
import ThirdParty

public struct OverlayView: View {
    @Bindable public var store: StoreOf<OverlayFeature>

    public init(store: StoreOf<OverlayFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            if let toastMessage = store.toastMessage {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.primary.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 24)
                        .onTapGesture {
                            store.send(.dismissToast)
                        }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: store.toastMessage)
        .alert(
            store.alertMessage ?? "",
            isPresented: Binding(
                get: { store.alertMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        store.send(.dismissAlert)
                    }
                }
            )
        ) {
            Button("확인", role: .cancel) {
                store.send(.dismissAlert)
            }
        }
    }
}
