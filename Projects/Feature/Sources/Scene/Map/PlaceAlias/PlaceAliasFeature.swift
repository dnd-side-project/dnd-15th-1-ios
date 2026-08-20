//
//  PlaceAliasFeature.swift
//  Dulpick
//

import Domain
import Foundation
import ThirdParty

@Reducer
public struct PlaceAliasFeature {
    /// 통과 기준. 규칙이 아직 없어 정한 값이라 이 한 줄만 바꾸면 된다
    static let maxAliasLength = 15

    /// 길이를 여기서 잘라 State.alias 를 항상 검증 가능한 값으로 둔다.
    /// 공백은 별칭에 뜻이 있어 남긴다. 앞뒤 공백만 저장 직전에 턴다
    static func sanitizedAlias(_ raw: String) -> String {
        String(raw.prefix(maxAliasLength))
    }

    @ObservableState
    public struct State: Equatable, Identifiable {
        public var id: String { placeID }

        public let placeID: String
        public let placeName: String
        /// 시안 a01 의 회색 주소 줄
        public let address: String

        public var alias: String

        public var trimmedAlias: String {
            alias.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        public var isSaveEnabled: Bool { !trimmedAlias.isEmpty }

        public init(savedPlace: SavedPlace) {
            placeID = savedPlace.id
            placeName = savedPlace.place.name
            address = savedPlace.place.roadAddress
            alias = PlaceAliasFeature.sanitizedAlias(savedPlace.alias ?? savedPlace.place.name)
        }
    }

    public enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)
        case saveTapped
        case dismissed
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 장소 id 와 다듬은 별칭. 받는 쪽이 목록을 갈아 끼운다
            case saved(String, String)
            case cancelled
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding:
            return .none

        case .saveTapped:
            guard state.isSaveEnabled else { return .none }
            return .send(.delegate(.saved(state.placeID, state.trimmedAlias)))

        case .dismissed:
            return .send(.delegate(.cancelled))

        case .delegate:
            return .none
        }
    }
}
