import ComposableArchitecture
import Domain
import SharedDesignSystem
import SwiftUI

// MARK: - CourseResultMetric

private enum CourseResultMetric {
    static let skeletonRowCount = 3
    static let skeletonRowHeight: CGFloat = 64
    static let cornerRadius: CGFloat = 12
    static let ctaButtonHeight: CGFloat = 56
    /// 타임라인 마지막 행과 CTA 버튼 윗면 사이
    static let listGapAboveCTA: CGFloat = 20
}

// MARK: - CourseResultView

/// 확정 저장한 데이트 코스를 지도와 시트로 보여주는 화면. 시안 c01 · c02.
public struct CourseResultView: View {
    @Bindable private var store: StoreOf<CourseResultFeature>

    /// 시트 단계. 시트가 접혀 있는지 펼쳐져 있는지다
    @State private var sheetDetent: SheetDetent = .collapsed

    @State private var collapsedSheetTop: CGFloat = 0
    @State private var grabFrames: [CGRect] = []

    public init(store: StoreOf<CourseResultFeature>) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                map
                backButtonLayer
                sheet
                if store.showsNotifyButton { cta }
            }
            .onChange(of: collapsedSheetTop) { _, newValue in
                store.send(.mapSizeChanged(width: proxy.size.width, visibleHeight: newValue))
            }
            .onChange(of: store.stops.count) { _, _ in
                store.send(.mapSizeChanged(width: proxy.size.width, visibleHeight: collapsedSheetTop))
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        // 네비바가 있으면 안전영역이 늘어 시트가 그만큼 내려앉는다
        .toolbar(.hidden, for: .navigationBar)
        .toast(item: toastBinding)
        .onAppear { store.send(.onAppear) }
    }
}

// MARK: - Layer

private extension CourseResultView {

    /// 마지막 행이 CTA 버튼 윗면에서 20 위에 서게 시트가 그만큼 더 올라간다.
    /// 아래 안전영역은 안 더한다. 이 화면의 시트와 CTA 가 둘 다 안전영역 바닥에 붙어
    /// 이미 그만큼 올라와 있다
    var ctaCoverPadding: CGFloat {
        Spacing.s20
            + CourseResultMetric.ctaButtonHeight
            + CourseResultMetric.listGapAboveCTA
    }

    var map: some View {
        DulpickMapView(
            camera: Binding(
                get: { store.camera },
                set: { store.send(.cameraChanged($0)) }
            ),
            markers: store.markers,
            routes: store.routes,
            collapsedSheetTop: collapsedSheetTop
        )
        .ignoresSafeArea()
    }

    /// 뒤로가기가 서치바 자리에 선다. 시트 펼침 한계가 그 자리를 기준으로 잡혀 있다
    var backButtonLayer: some View {
        BackButton { store.send(.backTapped) }
            .padding(.leading, BackButtonMetric.leadingInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var sheet: some View {
        MapBottomSheet(
            selection: $sheetDetent,
            expandLimit: .belowSearchBar,
            grabFrames: grabFrames,
            gestureKind: .grabberOnly,
            onCollapsedTopChange: { collapsedSheetTop = $0 }
        ) {
            EmptyView()
        } header: {
            sheetHeader
        } content: {
            sheetContent
        }
    }

    var cta: some View {
        CTAContainer {
            AppButton(
                store.notifyTitle,
                icon: .alarm,
                style: .primary,
                size: .xl,
                fullWidth: true
            ) {
                store.send(.notifyTapped)
            }
            .disabled(store.isNotifyingPartner)
        }
    }

    var sheetHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.s8) {
            HStack(alignment: .top, spacing: Spacing.s8) {
                Text(store.course?.title ?? "")
                    .typography(.title3SB)
                    .foregroundStyle(Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // 지난 데이트로 들어오면 수정을 안 낸다. 제목이 그 폭을 가져간다
                if store.showsEditButton {
                    AppButton("수정", style: .outlined, size: .sm) {
                        store.send(.editTapped)
                    }
                }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                if grabFrames != [$0] { grabFrames = [$0] }
            }

            if let summaryText = store.summaryText {
                Text(summaryText)
                    .typography(.body2M)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.bottom, Spacing.s8)
    }

    @ViewBuilder
    var sheetContent: some View {
        switch store.loadState {
        case .loading:
            skeleton
        case .failed:
            failureState
        case .loaded:
            timeline
        }
    }

    var timeline: some View {
        CourseTimeline(stops: store.timelineStops, legs: store.timelineLegs)
            .padding(.horizontal, Spacing.s24)
            .padding(.bottom, store.showsNotifyButton ? ctaCoverPadding : Spacing.s20)
    }

    var skeleton: some View {
        VStack(spacing: Spacing.s16) {
            ForEach(0 ..< CourseResultMetric.skeletonRowCount, id: \.self) { _ in
                ShimmerBlock(cornerRadius: CourseResultMetric.cornerRadius)
                    .frame(height: CourseResultMetric.skeletonRowHeight)
            }
        }
        .padding(.horizontal, Spacing.s20)
        .padding(.top, Spacing.s8)
    }

    var failureState: some View {
        EmptyStateView(
            image: .placeEmpty,
            title: "코스를 불러오지 못했어요",
            message: "잠시 뒤 다시 시도해주세요"
        )
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.s32)
    }

    var toastBinding: Binding<ToastState?> {
        Binding(
            get: { store.toast },
            set: { newValue in
                if newValue == nil {
                    store.send(.toastDismissed)
                }
            }
        )
    }
}

#if DEBUG

// MARK: - Preview

private extension Place {
    static func preview(id: String, latitude: Double, longitude: Double) -> Place {
        Place(
            id: id,
            kakaoPlaceID: nil,
            name: "장소명",
            category: .food,
            address: "경기도 안산시 모모로 145길 (뭐뭐동)",
            roadAddress: "경기도 안산시 모모로 145길 (뭐뭐동)",
            coordinate: Coordinate(latitude: latitude, longitude: longitude),
            bookmarkCount: 0,
            thumbnailURLs: []
        )
    }
}

private enum CourseResultPreviewData {
    static let title = "26.08.05 데이트"
    static let scheduledDate = Date(timeIntervalSince1970: 1_785_931_200)
    static let scheduledTime = DateComponents(hour: 13, minute: 0)
    static let shortLeg = Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500)
    static let longLeg = Domain.CourseLeg(walkingMinutes: 80, distanceMeters: 5300)

    static let stops: [Domain.CourseStop] = [
        Domain.CourseStop(place: .preview(id: "p0", latitude: 37.3128, longitude: 126.9040)),
        Domain.CourseStop(place: .preview(id: "p1", latitude: 37.3084, longitude: 126.9061)),
        Domain.CourseStop(place: .preview(id: "p2", latitude: 37.3141, longitude: 126.9068)),
    ]

    static let threeStops = DateCourse(
        id: "1",
        title: title,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        status: .confirmed,
        version: 1,
        stops: stops,
        legs: [shortLeg, longLeg]
    )

    static let missingFirstLeg = DateCourse(
        id: "1",
        title: title,
        scheduledDate: scheduledDate,
        scheduledTime: scheduledTime,
        status: .confirmed,
        version: 1,
        stops: stops,
        legs: [nil, longLeg]
    )
}

@MainActor
private func courseResultStore(course: DateCourse) -> StoreOf<CourseResultFeature> {
    Store(
        initialState: CourseResultFeature.State(
            course: course,
            dateCourseID: "1",
            partnerNickname: "당근맛감자채"
        )
    ) {
        CourseResultFeature()
    }
}

// c01 · c02 — 장소 3곳, 둘째 구간만 이동이 길다. 시트는 접힘만
#Preview("3곳") {
    KakaoMapPreviewContainer {
        CourseResultView(store: courseResultStore(course: CourseResultPreviewData.threeStops))
    }
}

// 첫 구간 walkToNext 없음. 구간 행과 점선은 남고 시간·거리 글자만 빈다
#Preview("도보 값 없는 구간") {
    KakaoMapPreviewContainer {
        CourseResultView(store: courseResultStore(course: CourseResultPreviewData.missingFirstLeg))
    }
}

// 재진입. GET 을 기다리는 loading
#Preview("조회 중") {
    KakaoMapPreviewContainer {
        CourseResultView(
            store: Store(
                initialState: CourseResultFeature.State(
                    course: nil,
                    dateCourseID: "1",
                    partnerNickname: "당근맛감자채"
                )
            ) {
                CourseResultFeature()
            } withDependencies: {
                $0.courseClient.course = { _ in
                    try await Task.never()
                }
            }
        )
    }
}

#endif
