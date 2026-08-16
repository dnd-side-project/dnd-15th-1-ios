import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct DateTypeView: View {
    static let tooltipText = "탐색 추천 알고리즘에 선호하시는 유형의 장소를\n우선 추천 하는데 사용되며 그렇지 않은\n데이트 장소도 추천 됩니다."

    @Bindable public var store: StoreOf<DateTypeFeature>

    public init(store: StoreOf<DateTypeFeature>) {
        self.store = store
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            axisList
                .disabled(store.isSubmitting)
                .padding(.horizontal, AxisListMetric.horizontalPadding)
                .padding(.top, HeaderMetric.bottomSpacing)

            Spacer(minLength: 0)

            CTAContainer {
                VStack(spacing: CTAMetric.spacing) {
                    skipButton
                    saveButton
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgDefault)
        // 버튼 밖 아무 데나 눌러도 닫힌다. 버튼 위 탭은 버튼이 먼저 가져가고, 닫기는 리듀서가 처리한다
        .gesture(
            TapGesture().onEnded { store.send(.tooltipDismissed) },
            including: store.isTooltipPresented ? .all : .subviews
        )
        .toast(item: toastBinding, bottomInset: toastBottomInset)
    }

    private var header: some View {
        VStack(spacing: 0) {
            titleRow
                .zIndex(1)

            // 세로가 모자라면 scaledToFit 이 비율을 지키며 이미지를 줄인다.
            // 그때 남는 분홍이 왼쪽에만 생기도록 오른쪽 끝에 붙인다
            Image.dateTypeGraphic
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.top, HeaderMetric.topPadding)
        .frame(maxWidth: .infinity)
        .background(Color.primaryPink.ignoresSafeArea(edges: .top))
    }

    private var titleRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("선호하는 데이트 방식을\n저장하면 장소를 추천드려요")
                .typography(.title2B)
                .foregroundStyle(Color.commonWhite)
                .frame(width: TitleRowMetric.width, alignment: .leading)

            tipButton

            Spacer(minLength: 0)
        }
        .frame(height: TitleRowMetric.height, alignment: .bottom)
        .padding(.horizontal, TitleRowMetric.horizontalPadding)
    }

    private var tipButton: some View {
        Button {
            store.send(.tooltipButtonTapped)
        } label: {
            Image.tip
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(Color.commonWhite)
                .frame(width: TipButtonMetric.iconSize, height: TipButtonMetric.iconSize)
                .frame(width: TipButtonMetric.width, height: TipButtonMetric.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) {
            if store.isTooltipPresented {
                DateTypeTooltip(
                    text: Self.tooltipText,
                    arrowTrailingInset: TooltipMetric.arrowTrailingInset
                )
                .offset(x: TooltipMetric.trailingOffset, y: TooltipMetric.topOffset)
            }
        }
    }

    private var axisList: some View {
        VStack(spacing: AxisListMetric.spacing) {
            DateTypeAxisRow(
                leading: .init(value: IndoorOutdoor.indoor, title: "실내", icon: .dateTypeIndoor),
                trailing: .init(value: IndoorOutdoor.outdoor, title: "실외", icon: .dateTypeOutdoor),
                selection: store.indoorOutdoor,
                onSelect: { store.send(.indoorOutdoorSelected($0)) }
            )

            DateTypeAxisRow(
                leading: .init(value: ActivityLevel.active, title: "액티비티", icon: .dateTypeActive),
                trailing: .init(value: ActivityLevel.static, title: "정적", icon: .dateTypeStatic),
                selection: store.activityLevel,
                onSelect: { store.send(.activityLevelSelected($0)) }
            )

            DateTypeAxisRow(
                leading: .init(value: DateTime.day, title: "낮 데이트", icon: .dateTypeDay),
                trailing: .init(value: DateTime.night, title: "밤 데이트", icon: .dateTypeNight),
                selection: store.dateTime,
                onSelect: { store.send(.dateTimeSelected($0)) }
            )

            DateTypeAxisRow(
                leading: .init(value: DateFocus.food, title: "식사 중심", icon: .dateTypeFood),
                trailing: .init(value: DateFocus.sightseeing, title: "볼거리 중심", icon: .dateTypeSightseeing),
                selection: store.dateFocus,
                onSelect: { store.send(.dateFocusSelected($0)) }
            )
        }
    }

    private var skipButton: some View {
        Button {
            store.send(.skipButtonTapped)
        } label: {
            Text("다음에 할래요")
                .typography(.body1SB)
                .foregroundStyle(Color.textTertiary)
                // 터치 범위는 글자 크기까지만. 폭을 늘리면 화면 전체가 눌린다
                .padding(.vertical, SkipButtonMetric.verticalPadding)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isSubmitting)
    }

    private var saveButton: some View {
        AppButton("저장", style: .dark, size: .xl, fullWidth: true) {
            store.send(.saveButtonTapped)
        }
        .disabled(!store.isSaveEnabled)
    }

    private var toastBottomInset: CGFloat {
        CTALayout.toastInset(
            contentHeight: CTALayout.textButtonHeight + CTAMetric.spacing + CTALayout.xlButtonHeight
        )
    }

    private var toastBinding: Binding<ToastState?> {
        Binding(
            get: { store.toast },
            set: { newValue in
                if newValue == nil {
                    store.send(.dismissToast)
                }
            }
        )
    }
}

private enum HeaderMetric {
    static let topPadding: CGFloat = 30
    static let bottomSpacing: CGFloat = 41
}

private enum TitleRowMetric {
    static let height: CGFloat = 66
    static let width: CGFloat = 233
    static let horizontalPadding: CGFloat = 20
}

private enum TipButtonMetric {
    static let width: CGFloat = 40
    static let height: CGFloat = 32
    static let iconSize: CGFloat = 18

    /// tip 버튼의 화면 기준 x. 제목 폭이 고정이라 화면 폭과 무관하다
    static let leadingX: CGFloat = TitleRowMetric.horizontalPadding + TitleRowMetric.width
    static let trailingX: CGFloat = leadingX + width
    static let centerX: CGFloat = leadingX + width / 2
}

enum TooltipMetric {
    /// 시안: 말풍선 왼쪽 끝이 화면 왼쪽에서 42
    static let leadingInset: CGFloat = 42
    /// 시안: 화살표 뾰족한 끝이 tip 버튼 하단에서 4 아래
    static let arrowGap: CGFloat = 4

    /// 말풍선은 tip 버튼 오른쪽 끝에 트레일링 정렬된다. 시안 위치까지 그만큼 오른쪽으로 민다
    static let trailingOffset: CGFloat =
        leadingInset + BubbleMetric.width - TipButtonMetric.trailingX
    /// overlay 의 y 원점은 tip 버튼 상단이고, 화살표 끝은 말풍선 상단보다 ArrowMetric.protrusion 만큼 위다
    static let topOffset: CGFloat =
        TipButtonMetric.height + arrowGap + ArrowMetric.protrusion
    /// 말풍선 왼쪽 끝이 42 로 고정이므로, 화살표가 tip 버튼 가운데를 가리키는 위치도 여기서 정해진다
    static let arrowTrailingInset: CGFloat =
        leadingInset + BubbleMetric.width - TipButtonMetric.centerX
}

private enum AxisListMetric {
    static let spacing: CGFloat = 32
    static let horizontalPadding: CGFloat = 20
}

private enum CTAMetric {
    static let spacing: CGFloat = 10
}

private enum SkipButtonMetric {
    static let verticalPadding: CGFloat = 4
}

#if DEBUG
#Preview("미선택") {
    DateTypeView(
        store: Store(initialState: DateTypeFeature.State()) {
            DateTypeFeature()
        }
    )
}

#Preview("실내 선택 · 툴팁") {
    DateTypeView(
        store: Store(
            initialState: DateTypeFeature.State(
                indoorOutdoor: .indoor,
                isTooltipPresented: true
            )
        ) {
            DateTypeFeature()
        }
    )
}

#Preview("전부 선택") {
    DateTypeView(
        store: Store(
            initialState: DateTypeFeature.State(
                indoorOutdoor: .indoor,
                activityLevel: .active,
                dateTime: .day,
                dateFocus: .food
            )
        ) {
            DateTypeFeature()
        }
    )
}
#endif
