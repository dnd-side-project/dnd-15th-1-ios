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

            VStack(spacing: IndicatorMetric.topSpacing) {
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
                        .frame(width: BackButtonMetric.iconSize, height: BackButtonMetric.iconSize)
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
                ForEach(Array(store.pages.enumerated()), id: \.offset) { index, item in
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
        VStack(spacing: PageMetric.titleSpacing) {
            Text(item.title)
                .typography(.title1B)
                .foregroundStyle(Color.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, PageMetric.titleHorizontalPadding)

            item.image
                .resizable()
                .scaledToFit()
                .frame(width: PageMetric.imageWidth, height: PageMetric.imageHeight)
        }
        .frame(maxWidth: .infinity)
    }

    private var pageIndicator: some View {
        HStack(spacing: IndicatorMetric.dotSpacing) {
            ForEach(0..<store.pageCount, id: \.self) { index in
                let isActive = index == store.pageIndex
                Capsule()
                    .fill(isActive ? Color.textPrimary : Color.borderDefault)
                    .frame(
                        width: isActive ? IndicatorMetric.activeDotWidth : IndicatorMetric.inactiveDotWidth,
                        height: IndicatorMetric.dotHeight
                    )
                    .animation(.easeInOut(duration: 0.25), value: isActive)
            }
        }
        .frame(height: IndicatorMetric.height)
        .animation(.easeInOut(duration: 0.25), value: store.pageIndex)
    }

    private var nextButton: some View {
        AppButton("다음", style: .dark, size: .xl, fullWidth: true) {
            store.send(.nextButtonTapped, animation: .easeInOut(duration: 0.25))
        }
        .padding(.horizontal, NextButtonMetric.horizontalPadding)
    }
}

private enum BackButtonMetric {
    static let iconSize: CGFloat = 24
}

private enum PageMetric {
    static let titleSpacing: CGFloat = 40
    static let titleHorizontalPadding: CGFloat = 20
    static let imageWidth: CGFloat = 340
    static let imageHeight: CGFloat = 300
}

private enum IndicatorMetric {
    static let topSpacing: CGFloat = 20
    static let dotSpacing: CGFloat = 8
    static let activeDotWidth: CGFloat = 17
    static let inactiveDotWidth: CGFloat = 8
    static let dotHeight: CGFloat = 8
    static let height: CGFloat = 32
}

private enum NextButtonMetric {
    static let horizontalPadding: CGFloat = 20
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
