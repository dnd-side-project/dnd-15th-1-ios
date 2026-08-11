import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct AppIntroView: View {
    @Bindable public var store: StoreOf<AppIntroFeature>
    @State private var scrollPageID: Int?

    public init(store: StoreOf<AppIntroFeature>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            rootContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.clear, for: .navigationBar)
                .toolbar { backToolbar }
                .onAppear { scrollPageID = store.pageIndex }
                .onChange(of: store.pageIndex, handlePageIndexChange)
                .onChange(of: scrollPageID, handleScrollPageIDChange)
        }
    }

    private var rootContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            VStack(spacing: 20) {
                pageScroll
                pageIndicator
            }

            Spacer(minLength: 0)

            nextButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDefault)
        .contentShape(Rectangle())
    }

    @ToolbarContentBuilder
    private var backToolbar: some ToolbarContent {
        if !store.isFirstPage {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    store.send(.backButtonTapped)
                } label: {
                    Image.arrowLeft
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: 24, height: 24)
                }
            }
        }
    }

    private func handlePageIndexChange(_ oldValue: Int, _ newValue: Int) {
        guard scrollPageID != newValue else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            scrollPageID = newValue
        }
    }

    private func handleScrollPageIDChange(_ oldValue: Int?, _ newValue: Int?) {
        guard let newValue, newValue != store.pageIndex else { return }
        store.send(.pageChanged(newValue), animation: .easeInOut(duration: 0.25))
    }

    private var pageScroll: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(AppIntroStep.pages.enumerated()), id: \.offset) { index, item in
                    page(item)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrollPageID)
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func page(_ item: AppIntroPage) -> some View {
        VStack(spacing: 40) {
            Text(item.title)
                .typography(.title1B)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            item.image
                .resizable()
                .scaledToFit()
                .frame(width: 340, height: 300)
        }
        .frame(maxWidth: .infinity)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<AppIntroStep.pages.count, id: \.self) { index in
                let isActive = index == store.pageIndex
                Capsule()
                    .fill(isActive ? Color.textPrimary : Color.borderDefault)
                    .frame(width: isActive ? 17 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: isActive)
            }
        }
        .frame(height: 32)
        .animation(.easeInOut(duration: 0.25), value: store.pageIndex)
    }

    private var nextButton: some View {
        AppButton("다음", style: .dark, size: .xl, fullWidth: true) {
            store.send(.nextButtonTapped, animation: .easeInOut(duration: 0.25))
        }
        .padding(.horizontal, 20)
    }
}

#if DEBUG
#Preview("page0") {
    AppIntroView(
        store: Store(initialState: AppIntroFeature.State(pageIndex: 0)) {
            AppIntroFeature()
        }
    )
}

#Preview("page1") {
    AppIntroView(
        store: Store(initialState: AppIntroFeature.State(pageIndex: 1)) {
            AppIntroFeature()
        }
    )
}

#Preview("page2") {
    AppIntroView(
        store: Store(initialState: AppIntroFeature.State(pageIndex: 2)) {
            AppIntroFeature()
        }
    )
}
#endif
