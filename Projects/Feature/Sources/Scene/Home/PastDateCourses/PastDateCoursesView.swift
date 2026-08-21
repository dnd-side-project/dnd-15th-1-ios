//
//  PastDateCoursesView.swift
//  Dulpick
//
//  Created by 이인호 on 8/21/26.
//

import Domain
import SharedDesignSystem
import SwiftUI
import ThirdParty

public struct PastDateCoursesView: View {
    public let store: StoreOf<PastDateCoursesFeature>

    public init(store: StoreOf<PastDateCoursesFeature>) {
        self.store = store
    }

    public var body: some View {
        content
            .navigationTitle("지난 데이트 일정")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar { backToolbar }
            .toolbar(.hidden, for: .tabBar)
            .background(Color.bgDefault)
            .onAppear { store.send(.onAppear) }
    }

    @ViewBuilder
    private var content: some View {
        if store.hasLoaded, store.courses.isEmpty {
            emptyState
        } else {
            listContent
        }
    }

    private var listContent: some View {
        ScrollView {
            VStack(spacing: 8) {
                countBanner
                    .padding(.bottom, 12)

                ForEach(store.courses) { course in
                    PastDateCourseRow(schedule: course)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
    }

    // 총 데이트 횟수 = 받은 리스트 개수
    private var countBanner: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack {
                Text("지금까지 총 \(store.count)번\n데이트 일정을 함께 했어요")
                    .typography(.title3SB)
                    .foregroundStyle(Color.textInverse)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            // 이미지는 배너 하단에 붙인다
            Image.bannerTogether
                .resizable()
                .scaledToFit()
                .frame(height: 100)
        }
        .frame(maxWidth: .infinity)
        .background(Color.primaryPink)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                Image.dateScheduleEmpty

                VStack(spacing: 4) {
                    Text("지난 데이트 일정이 없어요")
                        .typography(.title3SB)
                        .foregroundStyle(Color.textPrimary)

                    Text("새로운 데이트 일정을 만들어보세요")
                        .typography(.body1M)
                        .foregroundStyle(Color.textTertiary)
                }
            }

            AppButton("일정 만들러가기", style: .outlined, size: .lg) {
                store.send(.createCourseTapped)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var backToolbar: some ToolbarContent {
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

// 지난 데이트 카드. 홈의 가로 카드와 달리 폭을 꽉 채운다
private struct PastDateCourseRow: View {
    let schedule: DateSchedule

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(schedule.title)
                .typography(.body1M)
                .foregroundStyle(Color.textPrimary)

            HStack {
                HStack(spacing: 2) {
                    Image.mappin
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .foregroundStyle(Color.primaryPink)

                    Text("총 \(schedule.placeCount)곳의 장소")
                        .typography(.body2M)
                        .foregroundStyle(Color.brandPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.commonWhite)
                .clipShape(Capsule())

                Spacer()

                Text(schedule.date)
                    .typography(.caption1R)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.bgSubtle)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
