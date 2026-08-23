//
//  PlaceAliasFeatureTests.swift
//  Dulpick
//

import ComposableArchitecture
import Domain
import XCTest

@testable import Feature

@MainActor
final class PlaceAliasFeatureTests: XCTestCase {
    func test_초기값은_기존별칭이고_없으면_장소명이다() async {
        let withAlias = SavedPlace.fixture(id: "7", alias: "우리 첫 카페")
        XCTAssertEqual(PlaceAliasFeature.State(savedPlace: withAlias).alias, "우리 첫 카페")

        let withoutAlias = SavedPlace.fixture(id: "7", alias: nil)
        XCTAssertEqual(PlaceAliasFeature.State(savedPlace: withoutAlias).alias, "장소 7")
    }

    func test_장소명이_열다섯자를_넘으면_초기값을_자른다() {
        let longName = String(repeating: "가", count: 16)
        let saved = SavedPlace.fixture(id: "7", alias: nil, name: longName)
        XCTAssertEqual(
            PlaceAliasFeature.State(savedPlace: saved).alias,
            String(repeating: "가", count: 15)
        )
    }

    func test_열여섯번째_글자는_들어가지_않는다() {
        let fifteen = String(repeating: "가", count: 15)
        XCTAssertEqual(PlaceAliasFeature.sanitizedAlias(fifteen + "나"), fifteen)
    }

    func test_열다섯자까지는_그대로_받는다() {
        let fifteen = String(repeating: "가", count: 15)
        XCTAssertEqual(PlaceAliasFeature.sanitizedAlias(fifteen), fifteen)
    }

    func test_공백만_있는_값은_저장을_끈다() async {
        let store = TestStore(
            initialState: PlaceAliasFeature.State(savedPlace: .fixture(id: "7", alias: nil))
        ) {
            PlaceAliasFeature()
        }

        await store.send(\.binding.alias, "   ") {
            $0.alias = "   "
        }
        XCTAssertFalse(store.state.isSaveEnabled)
    }

    func test_저장을_누르면_다듬은_별칭을_올린다() async {
        let saved = SavedPlace.fixture(id: "7", alias: nil)
        let updated = SavedPlace(
            place: saved.place,
            ownership: saved.ownership,
            alias: "우리 첫 카페",
            memo: saved.memo,
            savedAt: saved.savedAt
        )
        let store = TestStore(
            initialState: PlaceAliasFeature.State(savedPlace: saved)
        ) {
            PlaceAliasFeature()
        } withDependencies: {
            $0.placeClient.updateAlias = { placeID, alias in
                XCTAssertEqual(placeID, 7)
                XCTAssertEqual(alias, "우리 첫 카페")
                return updated
            }
        }

        await store.send(\.binding.alias, "  우리 첫 카페  ") {
            $0.alias = "  우리 첫 카페  "
        }
        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.aliasSaved(updated)) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved(updated)))
    }

    func test_닫으면_취소를_올린다() async {
        let store = TestStore(
            initialState: PlaceAliasFeature.State(savedPlace: .fixture(id: "7", alias: nil))
        ) {
            PlaceAliasFeature()
        }

        await store.send(.dismissed)
        await store.receive(\.delegate.cancelled)
    }

    func test_공백만_넣고_저장을_누르면_아무_것도_안_올린다() async {
        let store = TestStore(
            initialState: PlaceAliasFeature.State(savedPlace: .fixture(id: "7", alias: nil))
        ) {
            PlaceAliasFeature()
        }

        await store.send(\.binding.alias, "   ") {
            $0.alias = "   "
        }
        await store.send(.saveTapped)
    }

    func test_저장이_성공하면_서버가_준_저장_장소를_올린다() async {
        let saved = SavedPlace.mocks[0]
        let updated = SavedPlace(
            place: saved.place,
            ownership: saved.ownership,
            alias: "우리 카페",
            memo: saved.memo,
            savedAt: saved.savedAt
        )
        let store = TestStore(initialState: PlaceAliasFeature.State(savedPlace: saved)) {
            PlaceAliasFeature()
        } withDependencies: {
            $0.placeClient.updateAlias = { placeID, alias in
                XCTAssertEqual(placeID, Int(saved.place.id))
                XCTAssertEqual(alias, "우리 카페")
                return updated
            }
        }

        await store.send(\.binding.alias, "우리 카페") {
            $0.alias = "우리 카페"
        }
        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.aliasSaved(updated)) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.saved(updated)))
    }

    func test_저장이_실패하면_시트가_안_닫히고_문구가_뜬다() async {
        let saved = SavedPlace.mocks[0]
        let store = TestStore(initialState: PlaceAliasFeature.State(savedPlace: saved)) {
            PlaceAliasFeature()
        } withDependencies: {
            $0.placeClient.updateAlias = { _, _ in throw PlaceError.network }
        }

        await store.send(\.binding.alias, "우리 카페") {
            $0.alias = "우리 카페"
        }
        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.aliasSaveFailed(.network)) {
            $0.isSaving = false
            $0.errorMessage = "잠시 뒤 다시 시도해주세요"
        }
    }

    func test_저장한_장소가_아니면_그_문구를_보인다() async {
        let saved = SavedPlace.mocks[0]
        let store = TestStore(initialState: PlaceAliasFeature.State(savedPlace: saved)) {
            PlaceAliasFeature()
        } withDependencies: {
            $0.placeClient.updateAlias = { _, _ in throw PlaceError.notFound }
        }

        await store.send(\.binding.alias, "우리 카페") {
            $0.alias = "우리 카페"
        }
        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.aliasSaveFailed(.notFound)) {
            $0.isSaving = false
            $0.errorMessage = "저장한 장소가 아니에요"
        }
    }

    func test_저장이_만료되면_세션만료를_올린다() async {
        let saved = SavedPlace.mocks[0]
        let store = TestStore(initialState: PlaceAliasFeature.State(savedPlace: saved)) {
            PlaceAliasFeature()
        } withDependencies: {
            $0.placeClient.updateAlias = { _, _ in throw PlaceError.unauthorized }
        }

        await store.send(\.binding.alias, "우리 카페") {
            $0.alias = "우리 카페"
        }
        await store.send(.saveTapped) {
            $0.isSaving = true
        }
        await store.receive(.aliasSaveFailed(.unauthorized)) {
            $0.isSaving = false
        }
        await store.receive(.delegate(.sessionExpired))
    }

    func test_저장_중에는_다시_누를_수_없다() async {
        let saved = SavedPlace.mocks[0]
        var state = PlaceAliasFeature.State(savedPlace: saved)
        state.isSaving = true
        let store = TestStore(initialState: state) { PlaceAliasFeature() }

        await store.send(.saveTapped)
    }
}
