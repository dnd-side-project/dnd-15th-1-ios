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
        let store = TestStore(
            initialState: PlaceAliasFeature.State(savedPlace: .fixture(id: "7", alias: nil))
        ) {
            PlaceAliasFeature()
        }

        await store.send(\.binding.alias, "  우리 첫 카페  ") {
            $0.alias = "  우리 첫 카페  "
        }
        await store.send(.saveTapped)
        await store.receive(.delegate(.saved("7", "우리 첫 카페")))
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
}
