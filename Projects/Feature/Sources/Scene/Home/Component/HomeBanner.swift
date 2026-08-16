//
//  HomeBanner.swift
//  Dulpick
//
//  Created by 이인호 on 8/10/26.
//

import Domain
import SharedDesignSystem
import SwiftUI

struct HomeBanner: View {
    let isConnected: Bool
    let upcomingSchedule: UpcomingSchedule?
    let connectTapped: () -> Void
    let bannerTapped: () -> Void

    var body: some View {
        Group {
            if !isConnected {
                connectBanner
            } else if let upcomingSchedule {
                upcomingBanner(upcomingSchedule)
            } else {
                courseBanner
            }
        }
        .padding(.horizontal, 20)
    }

    private let connectTitle = "커플 연결 후 연인과 함께\n데이트 장소를 픽해보세요!"

    private var connectBanner: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                Text(connectTitle)
                    .typography(.title3SB)
                    .multilineTextAlignment(.center)
                    .padding(.top, 36)
                    .hidden()

                Image.bannerCoupleConnect
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 0) {
                Text(connectTitle)
                    .typography(.title3SB)
                    .foregroundStyle(Color.commonWhite)
                    .multilineTextAlignment(.center)
                    .padding(.top, 36)

                connectButton
                    .padding(.top, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.primaryPink)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    private var connectButton: some View {
        Button(action: connectTapped) {
            Text("커플 연결하러가기")
                .typography(.body1SB)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.commonWhite)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.gray200, lineWidth: 1)
                }
        }
    }

    private var courseBanner: some View {
        Button(action: bannerTapped) {
            HStack {
                VStack(alignment: .leading, spacing: 10) {
                    Text("이번주 데이트 코스를")
                        .typography(.title3SB)
                        .foregroundStyle(Color.commonWhite)

                    HStack(spacing: 4) {
                        Text("함께 정해볼까요?")
                            .typography(.title3SB)
                            .foregroundStyle(Color.commonWhite)

                        Image.arrow2
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(Color.commonWhite)
                    }
                }

                Spacer()

                Image.bannerPeek
            }
            .padding(.leading, 24)
            .frame(maxWidth: .infinity)
            .background(Color.primaryPink)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func upcomingBanner(_ schedule: UpcomingSchedule) -> some View {
        Button(action: bannerTapped) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(schedule.date) 데이트 일정")
                        .typography(.title3SB)
                        .foregroundStyle(Color.commonWhite)

                    Text("총 \(schedule.placeCount)곳의 장소")
                        .typography(.body2M)
                        .foregroundStyle(Color.commonWhite)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.commonWhite.opacity(0.2))
                        .clipShape(Capsule())
                }

                Spacer()

                Image.bannerCalendar
            }
            .padding(.leading, 24)
            .frame(maxWidth: .infinity)
            .background(Color.primaryPink)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
