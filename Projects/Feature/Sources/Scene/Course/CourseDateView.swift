import ComposableArchitecture
import SharedDesignSystem
import SwiftUI

// MARK: - CourseDateViewMetric

private enum CourseDateViewMetric {
    /// 시안 b01 기준. Spacing 토큰에 28 이 없다
    static let titleTopPadding: CGFloat = 28
    static let subtitleTopPadding: CGFloat = Spacing.s8
    static let fieldsTopPadding: CGFloat = Spacing.s32
    static let backButtonSide: CGFloat = 24
    static let sheetAnimationDuration: Duration = .seconds(Motion.sheetDuration)
}

// MARK: - CourseDateView

/// 데이트 날짜 선택 화면. 시안 b01 · b02 · b03.
///
/// 날짜는 필수, 시간은 선택이다. `다음` 은 늘 눌리고 누를 때 날짜만 검증한다.
public struct CourseDateView: View {
    @Bindable private var store: StoreOf<CourseFeature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<CourseFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .bottomSheet(isPresented: isWheelPresented, showsHandle: false) {
                wheelSheet
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("데이트 날짜 선택")
                        .typography(.body1SB)
                        .foregroundStyle(Color.gray900)
                }
                ToolbarItem(placement: .topBarLeading) {
                    backButton
                }
            }
            .task { store.send(.onAppear) }
    }
}

// MARK: - Layer

private extension CourseDateView {

    var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                title
                    .padding(.top, CourseDateViewMetric.titleTopPadding)

                Text("데이트 날짜가 지나면 지난 데이트 코스에 저장됩니다.")
                    .typography(.body2M)
                    .foregroundStyle(Color.textTertiary)
                    .padding(.top, CourseDateViewMetric.subtitleTopPadding)

                fields
                    .padding(.top, CourseDateViewMetric.fieldsTopPadding)
            }
            .padding(.horizontal, Spacing.s20)

            Spacer(minLength: 0)

            CTAContainer {
                AppButton("다음", style: .dark, size: .xl, fullWidth: true) {
                    store.send(.nextTapped)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgDefault)
    }

    @ViewBuilder
    var title: some View {
        if let nickname = store.partnerNickname {
            Text("\(nickname)님과의 데이트\n언제 만날까요?")
                .typography(.title2B)
                .foregroundStyle(Color.textPrimary)
        } else {
            Text("언제 만날까요?")
                .typography(.title2B)
                .foregroundStyle(Color.textPrimary)
        }
    }

    var fields: some View {
        VStack(spacing: Spacing.s12) {
            CourseInputField(
                value: store.dateText,
                placeholder: "날짜를 입력하세요",
                icon: .calendar,
                errorMessage: store.showsDateError ? "날짜를 필수로 입력해주세요" : nil
            ) {
                store.send(.dateFieldTapped)
            }

            CourseInputField(
                value: store.timeText,
                placeholder: "시간을 입력하세요",
                icon: .clock
            ) {
                store.send(.timeFieldTapped)
            }
        }
    }

    var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image.arrowLeft
                .renderingMode(.template)
                .resizable()
                .frame(
                    width: CourseDateViewMetric.backButtonSide,
                    height: CourseDateViewMetric.backButtonSide
                )
                .foregroundStyle(Color.textSecondary)
        }
    }

    var isWheelPresented: Binding<Bool> {
        Binding(
            get: { store.activeWheel != nil },
            set: { isPresented in
                guard !isPresented else { return }
                store.send(.wheelDismissed)
            }
        )
    }

    @ViewBuilder
    var wheelSheet: some View {
        WheelSheet(
            onConfirm: { store.send(.wheelConfirmed) }
        ) {
            DeferredWheel(
                activeWheel: store.activeWheel,
                draftDate: draftDateBinding,
                draftTime: draftTimeBinding,
                today: store.today
            )
        }
    }

    var draftDateBinding: Binding<DateComponents> {
        Binding(
            get: { store.draftDate },
            set: { store.send(.wheelDraftChanged($0)) }
        )
    }

    var draftTimeBinding: Binding<DateComponents> {
        Binding(
            get: { store.draftTime },
            set: { store.send(.wheelDraftChanged($0)) }
        )
    }
}

// MARK: - DeferredWheel

/// 시트가 삽입되는 프레임에 글자 54개(연 11 + 월 12 + 일 31)를 만들면 올라오는 움직임이 끊긴다.
/// BottomSheet 애니메이션이 끝난 뒤에 휠을 붙인다.
private struct DeferredWheel: View {
    let activeWheel: CourseFeature.WheelTarget?
    @Binding var draftDate: DateComponents
    @Binding var draftTime: DateComponents
    let today: DateComponents
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
                        yearRange: 2024 ... 2034,
                        minimum: today
                    )
                case .time:
                    TimeWheelPicker(selection: $draftTime, minuteStep: 5)
                case .none:
                    EmptyView()
                }
            }
        }
        .task {
            do {
                try await Task.sleep(for: CourseDateViewMetric.sheetAnimationDuration)
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

// b01 — 빈 상태
#Preview("빈 입력") {
    NavigationStack {
        CourseDateView(
            store: Store(initialState: CourseFeature.State()) {
                CourseFeature()
            }
        )
    }
}

#endif
