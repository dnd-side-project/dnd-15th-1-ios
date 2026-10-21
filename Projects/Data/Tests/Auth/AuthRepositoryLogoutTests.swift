import CoreNetwork
import CoreStorage
import Domain
import Foundation
import XCTest

@testable import Data

final class AuthRepositoryLogoutTests: XCTestCase {
    func test_logout_요청이_401이면_재발급한_뒤_새_리프레시_토큰으로_한_번_더_보낸다() async throws {
        let plain = ScriptedNetworkClient()
        await plain.reply(
            AuthSessionStoreFixture.reissueReply(access: "new-access", refresh: "new-refresh"),
            to: AuthStubFixture.reissuePath
        )
        let authed = ScriptedNetworkClient()
        await authed.reply(.failure(.unauthorized), to: AuthStubFixture.logoutPath)
        await authed.reply(.empty, to: AuthStubFixture.logoutPath)
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(access: "old-access", refresh: "old-refresh"),
            server: plain
        )
        let repository = AuthRepository.stub(plainClient: plain, authedClient: authed, sessionStore: store)

        try await repository.logout()

        let sent = AuthSessionStoreFixture.refreshTokens(in: await authed.bodies(of: AuthStubFixture.logoutPath))
        XCTAssertEqual(sent, ["old-refresh", "new-refresh"])
        let inMemory = try await store.currentSession()
        XCTAssertNil(inMemory)
    }

    func test_logout_키체인_삭제가_실패하면_storage로_알리고_세션은_메모리에서_지운다() async throws {
        let plain = ScriptedNetworkClient()
        let authed = ScriptedNetworkClient()
        await authed.reply(.empty, to: AuthStubFixture.logoutPath)
        let keychain = SerialKeychainStorage()
        let store = try await AuthSessionStoreFixture.makeStore(
            seed: AuthSessionStoreFixture.session(),
            keychain: keychain,
            server: plain
        )
        await keychain.setDeleteError(KeychainError.deleteFailed(status: -1))
        let repository = AuthRepository.stub(plainClient: plain, authedClient: authed, sessionStore: store)

        await assertThrows(AuthError.storage) {
            try await repository.logout()
        }

        let inMemory = try await store.currentSession()
        XCTAssertNil(inMemory)
    }
}
