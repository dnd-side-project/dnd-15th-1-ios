import Domain
import Feature
import SwiftUI
import ThirdParty
import UIKit
import XCTest

/// phase 가 바뀌면 온보딩 스택은 화면에 붙은 채로 걷힌다.
/// 그때 사라지는 화면이 액션을 더 보내면 RootFlow 는 이미 없는 상태로 그걸 받는다.
/// 창에 실제로 띄워야만 재현되므로 TestStore 대신 UIWindow 로 확인한다
@MainActor
final class RootFlowViewLifecycleTests: XCTestCase {
    func test_데이트유형_건너뛰기_뒤에_커플화면이_액션을_보내지_않는다() async {
        let harness = Harness(
            phase: .onboardingFlow(
                OnboardingFlowFeature.State(
                    nickname: NicknameFeature.State(isTermsSheetPresented: false),
                    couple: connectedCoupleState,
                    dateType: DateTypeFeature.State(),
                    path: [.nickname, .couple]
                )
            )
        )

        await harness.present()
        harness.store.send(.onboardingFlow(.dateType(.skipButtonTapped)))
        await harness.settle()

        harness.assertNoOnboardingFlowActionAfterCompletion()
        harness.dismiss()
    }

    func test_온보딩_완료로_phase가_바뀌어도_스택이_액션을_보내지_않는다() async {
        let harness = Harness(
            phase: .onboardingFlow(
                OnboardingFlowFeature.State(
                    nickname: NicknameFeature.State(isTermsSheetPresented: false),
                    couple: connectedCoupleState,
                    path: [.nickname, .couple]
                )
            )
        )

        await harness.present()
        harness.store.send(.onboardingFlow(.delegate(.onboardingCompleted)))
        await harness.settle()

        harness.assertNoOnboardingFlowActionAfterCompletion()
        harness.dismiss()
    }

    /// 코드를 이미 받은 상태로 시작해 네트워크 없이 커플 화면을 그린다
    private var connectedCoupleState: CoupleConnectFeature.State {
        CoupleConnectFeature.State(
            myNickname: "둘픽",
            inviteCode: InviteCode(value: "AB12C", shareURL: nil)
        )
    }
}

@MainActor
private final class Harness {
    let store: StoreOf<RootFlowFeature>

    private let recorded = LockIsolated<[String]>([])
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))

    init(phase: RootFlowFeature.State.Phase) {
        let recorded = self.recorded
        store = withDependencies {
            $0.authClient.currentSession = {
                AuthSession(accessToken: "access", refreshToken: "refresh", userID: "1")
            }
            // mainTab 전환 시 홈 onAppear 가 호출하므로 네트워크 없이 응답만 준다
            $0.coupleClient.current = { nil }
            $0.placeClient.savedPlaces = { [] }
            $0.profileClient.member = { UserProfile(nickname: "둘픽", iconID: 0, datePreference: nil) }
            $0.exploreClient.contents = { _, _, _ in
                ContentPage(items: [], hasNext: false, popularTags: [])
            }
        } operation: {
            Store(initialState: RootFlowFeature.State(phase: phase)) {
                Reduce<RootFlowFeature.State, RootFlowFeature.Action> { _, action in
                    let name = "\(action)"
                    recorded.withValue { $0.append(name) }
                    return .none
                }
                RootFlowFeature()
            }
        }
    }

    func present() async {
        window.rootViewController = UIHostingController(
            rootView: RootFlowView(store: store)
        )
        window.makeKeyAndVisible()
        await settle(1)
        recorded.withValue { $0.removeAll() }
    }

    func dismiss() {
        window.isHidden = true
        window.rootViewController = nil
    }

    func settle(_ seconds: Double = 2) async {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    func assertNoOnboardingFlowActionAfterCompletion(
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actions = recorded.value
        guard let completed = actions.firstIndex(where: { $0.contains("onboardingCompleted") }) else {
            XCTFail("온보딩 완료가 도착하지 않았다: \(actions)", file: file, line: line)
            return
        }
        let leaked = actions[actions.index(after: completed)...]
            .filter { $0.hasPrefix("onboardingFlow") }
        XCTAssertEqual(leaked, [], "onboardingFlow 상태가 사라진 뒤 자식 액션이 도착했다", file: file, line: line)
    }
}
