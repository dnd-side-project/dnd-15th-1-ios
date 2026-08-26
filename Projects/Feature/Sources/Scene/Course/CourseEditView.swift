import ComposableArchitecture
import Domain
import SharedDesignSystem
import SwiftUI

// MARK: - CourseEditMetric

private enum CourseEditMetric {
    static let titleTopPadding: CGFloat = Spacing.s8
    static let titleFieldHeight: CGFloat = 48
    static let titleFieldCornerRadius: CGFloat = 12
    static let trashIconSide: CGFloat = 24
    static let toastInset = CTALayout.toastInset(buttonHeights: [CTALayout.xlButtonHeight])
    static let sheetAnimationDuration: Duration = .seconds(Motion.sheetDuration)
    static let skeletonSectionTitleWidth: CGFloat = 100
    static let skeletonSectionTitleHeight: CGFloat = 30
    static let skeletonSectionTitleCornerRadius: CGFloat = 4
    static let skeletonPlaceCardCount = 3
    static let skeletonPlaceCardHeight: CGFloat = 81
    static let skeletonPlaceCardCornerRadius: CGFloat = 16
}

// MARK: - CourseEditView

/// 저장된 코스의 제목·날짜·시간·장소를 고치는 화면. 시안 c04 ~ c10.
public struct CourseEditView: View {
    @Bindable private var store: StoreOf<CourseEditFeature>

    public init(store: StoreOf<CourseEditFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .background(Color.bgDefault)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                BackToolbarItem { store.send(.backTapped) }
            }
            .toast(
                item: toastBinding,
                bottomInset: CourseEditMetric.toastInset
            ) {
                store.send(.undoTapped)
            }
            .modal(isPresented: backModalBinding) {
                ModalContent(
                    title: "변경사항을 저장할까요?",
                    content: "작성중인 내용이 있어요",
                    image: .saveModal,
                    primaryTitle: "네, 저장할래요",
                    primaryAction: { store.send(.backModalSaveTapped) },
                    secondaryTitle: "아니요",
                    secondaryAction: { store.send(.backModalDiscarded) },
                    primaryEnabled: store.canSave,
                    onClose: { store.send(.backModalClosed) }
                )
            }
            .bottomSheet(
                isPresented: isWheelPresented,
                showsHandle: false,
                onDismissed: { store.send(.wheelDismissFinished) }
            ) {
                wheelSheet
            }
            .onAppear { store.send(.onAppear) }
            .blocksSwipeBack(store.hasChanges)
    }
}

// MARK: - Layer

private extension CourseEditView {

    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch store.loadState {
            case .loading:
                skeleton
            case .failed:
                failureState
            case .loaded:
                loadedContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var skeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.s32) {
                skeletonInfoSection
                skeletonPlaceSection
            }
            .padding(.top, CourseEditMetric.titleTopPadding)
            .padding(.horizontal, Spacing.s20)
            .padding(.bottom, Spacing.s20)
        }
    }

    var skeletonInfoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            ShimmerBlock(cornerRadius: CourseEditMetric.skeletonSectionTitleCornerRadius)
                .frame(
                    width: CourseEditMetric.skeletonSectionTitleWidth,
                    height: CourseEditMetric.skeletonSectionTitleHeight
                )

            ShimmerBlock(cornerRadius: CourseEditMetric.titleFieldCornerRadius)
                .frame(height: CourseEditMetric.titleFieldHeight)

            HStack(spacing: Spacing.s12) {
                ShimmerBlock(cornerRadius: CourseEditMetric.titleFieldCornerRadius)
                    .frame(maxWidth: .infinity)
                    .frame(height: CourseEditMetric.titleFieldHeight)
                ShimmerBlock(cornerRadius: CourseEditMetric.titleFieldCornerRadius)
                    .frame(maxWidth: .infinity)
                    .frame(height: CourseEditMetric.titleFieldHeight)
            }
        }
    }

    var skeletonPlaceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShimmerBlock(cornerRadius: CourseEditMetric.skeletonSectionTitleCornerRadius)
                .frame(
                    width: CourseEditMetric.skeletonSectionTitleWidth,
                    height: CourseEditMetric.skeletonSectionTitleHeight
                )

            VStack(spacing: Spacing.s20) {
                ForEach(0 ..< CourseEditMetric.skeletonPlaceCardCount, id: \.self) { _ in
                    ShimmerBlock(cornerRadius: CourseEditMetric.skeletonPlaceCardCornerRadius)
                        .frame(height: CourseEditMetric.skeletonPlaceCardHeight)
                }
            }
            .padding(.top, Spacing.s12)
        }
    }

    var loadedContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                form
                    .padding(.horizontal, Spacing.s20)
                    .padding(.bottom, Spacing.s20)
            }
            CTAContainer {
                AppButton("저장", style: .dark, size: .xl, fullWidth: true) {
                    store.send(.saveTapped)
                }
                .disabled(!store.canSave)
            }
        }
    }

    var form: some View {
        VStack(alignment: .leading, spacing: Spacing.s32) {
            infoSection
            placeSection
        }
        .padding(.top, CourseEditMetric.titleTopPadding)
    }

    var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.s12) {
            Text("데이트 정보")
                .typography(.title3SB)
                .foregroundStyle(Color.textPrimary)

            titleField
            dateTimeRow
        }
    }

    var titleField: some View {
        AppTextField(
            text: Binding(
                get: { store.title },
                set: { store.send(.titleChanged($0)) }
            ),
            placeholder: "데이트명 입력",
            size: .medium,
            style: .filled
        )
    }

    var dateTimeRow: some View {
        HStack(spacing: Spacing.s12) {
            CourseInputField(
                value: store.dateText,
                // 두 칸이 나란히 놓여 폭이 절반이다. 긴 문구는 두 줄로 접힌다
                placeholder: "날짜 입력",
                icon: .calendar
            ) {
                store.send(.dateFieldTapped)
            }

            CourseInputField(
                value: store.timeText,
                placeholder: "시간 입력",
                icon: .clock
            ) {
                store.send(.timeFieldTapped)
            }
        }
    }

    var placeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("데이트 장소")
                .typography(.title3SB)
                .foregroundStyle(Color.textPrimary)

            placeList
                .padding(.top, Spacing.s12)

            addPlaceButton
                .padding(.top, Spacing.s24)
        }
    }

    var placeList: some View {
        ReorderableList(
            items: store.places,
            onMove: { store.send(.placeMoved(from: $0, to: $1)) },
            rowTitle: \.name,
            rowSubtitle: \.address,
            rowCategory: { $0.category.displayName }
        ) { place in
            Button {
                store.send(.placeDeleteTapped(id: place.id))
            } label: {
                Image.trash
                    .renderingMode(.template)
                    .resizable()
                    .frame(
                        width: CourseEditMetric.trashIconSide,
                        height: CourseEditMetric.trashIconSide
                    )
                    .foregroundStyle(Color.textTertiary)
            }
            .buttonStyle(.plain)
        }
    }

    var addPlaceButton: some View {
        HStack {
            Spacer(minLength: 0)
            AppButton("장소 추가", icon: .plus, style: .outlined, size: .lg) {
                store.send(.addPlaceTapped)
            }
            Spacer(minLength: 0)
        }
    }

    var failureState: some View {
        VStack(spacing: Spacing.s16) {
            EmptyStateView(
                image: .placeEmpty,
                title: "코스를 불러오지 못했어요",
                message: "잠시 뒤 다시 시도해주세요"
            )

            AppButton("다시 시도", style: .outlined, size: .md) {
                store.send(.retryTapped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var isWheelPresented: Binding<Bool> {
        Binding(
            get: { store.isWheelPresented },
            set: { isPresented in
                guard !isPresented else { return }
                store.send(.wheelDismissed)
            }
        )
    }

    var wheelSheet: some View {
        WheelSheet(onConfirm: { store.send(.wheelConfirmed) }) {
            DeferredWheel(
                activeWheel: store.activeWheel,
                draftDate: draftDateBinding,
                draftTime: draftTimeBinding,
                tomorrow: store.tomorrow
            )
        }
    }

    var draftDateBinding: Binding<DateComponents> {
        Binding(
            get: { store.draftDate },
            set: { store.send(.wheelDraftChanged(.date, $0)) }
        )
    }

    var draftTimeBinding: Binding<DateComponents> {
        Binding(
            get: { store.draftTime },
            set: { store.send(.wheelDraftChanged(.time, $0)) }
        )
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

    var backModalBinding: Binding<Bool> {
        Binding(
            get: { store.isBackModalPresented },
            set: { isPresented in
                if !isPresented {
                    store.send(.backModalClosed)
                }
            }
        )
    }
}

// MARK: - DeferredWheel

/// 시트가 삽입되는 프레임에 글자를 만들면 올라오는 움직임이 끊긴다.
/// BottomSheet 애니메이션이 끝난 뒤에 휠을 붙인다.
private struct DeferredWheel: View {
    let activeWheel: CourseEditFeature.Wheel?
    @Binding var draftDate: DateComponents
    @Binding var draftTime: DateComponents
    let tomorrow: DateComponents
    @State private var isReady = false

    var body: some View {
        ZStack {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: WheelMetrics.areaHeight)

            if isReady {
                switch activeWheel {
                case .date:
                    DateWheelPicker(
                        selection: $draftDate,
                        yearRange: 2024 ... 2028,
                        minimum: tomorrow
                    )
                case .time:
                    TimeWheelPicker(
                        selection: $draftTime,
                        minuteStep: 5
                    )
                case .none:
                    EmptyView()
                }
            }
        }
        .task {
            do {
                try await Task.sleep(for: CourseEditMetric.sheetAnimationDuration)
            } catch {
                return
            }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isReady = true
            }
        }
    }
}

#if DEBUG

// MARK: - Preview

private extension Place {
    static func editPreview(id: String, latitude: Double, longitude: Double) -> Place {
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

private enum CourseEditPreviewData {
    static let course = DateCourse(
        id: "1",
        title: "26.08.05 데이트",
        scheduledDate: Date(timeIntervalSince1970: 1_785_931_200),
        scheduledTime: DateComponents(hour: 13, minute: 0),
        status: .confirmed,
        version: 1,
        stops: [
            Domain.CourseStop(place: .editPreview(id: "p0", latitude: 37.3128, longitude: 126.9040)),
            Domain.CourseStop(place: .editPreview(id: "p1", latitude: 37.3084, longitude: 126.9061)),
            Domain.CourseStop(place: .editPreview(id: "p2", latitude: 37.3141, longitude: 126.9068)),
        ],
        legs: [
            Domain.CourseLeg(walkingMinutes: 20, distanceMeters: 1500),
            Domain.CourseLeg(walkingMinutes: 80, distanceMeters: 5300),
        ]
    )
}

@MainActor
private func courseEditStore(
    course: DateCourse = CourseEditPreviewData.course
) -> StoreOf<CourseEditFeature> {
    Store(initialState: CourseEditFeature.State(dateCourseID: course.id)) {
        CourseEditFeature()
    } withDependencies: {
        $0.courseClient.course = { _ in course }
    }
}

// c04
#Preview("3곳") {
    CourseEditView(store: courseEditStore())
}

#Preview("조회 중") {
    CourseEditView(
        store: Store(initialState: CourseEditFeature.State(dateCourseID: "1")) {
            CourseEditFeature()
        } withDependencies: {
            $0.courseClient.course = { _ in
                try await Task.never()
            }
        }
    )
}

#endif
