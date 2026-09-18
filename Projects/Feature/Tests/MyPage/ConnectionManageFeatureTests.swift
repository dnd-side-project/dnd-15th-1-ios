import ComposableArchitecture
import Domain
@testable import Feature
import XCTest

private let manageMe = CoupleMember(nickname: "둘픽", iconID: 1)
private let managePartner = CoupleMember(nickname: "픽둘", iconID: 2)

@MainActor
final class ConnectionManageFeatureTests: XCTestCase {
    func test_다시_읽어_연결됨이면_세_값을_채운다() async {
        let status = CoupleStatus.connected(me: manageMe, partner: managePartner, daysTogether: 30)
        let store = TestStore(initialState: ConnectionManageFeature.State()) {
            ConnectionManageFeature()
        } withDependencies: {
            $0.coupleClient.current = { status }
        }

        await store.send(.onAppear)
        await store.receive(.coupleLoaded(status)) {
            $0.me = manageMe
            $0.partner = managePartner
            $0.daysTogether = 30
        }
    }

    func test_다시_읽어_연결_안_됨이면_내_정보는_두고_상대와_함께한_날만_비운다() async {
        let store = TestStore(
            initialState: ConnectionManageFeature.State(me: manageMe, partner: managePartner, daysTogether: 30)
        ) {
            ConnectionManageFeature()
        } withDependencies: {
            $0.coupleClient.current = { .notConnected }
        }

        await store.send(.onAppear)
        await store.receive(.coupleLoaded(.notConnected)) {
            $0.partner = nil
            $0.daysTogether = nil
        }

        XCTAssertEqual(store.state.me, manageMe)
    }
}
