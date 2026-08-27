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
        /// 저장 요청이 도는 동안 참이다. 버튼을 잠그고 두 번 눌리는 것을 막는다
        public var isSaving = false
        /// 실패 문구. 입력칸 아래에 뜬다
        public var errorMessage: String?

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
        case aliasSaved(SavedPlace)
        case aliasSaveFailed(PlaceError)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// 서버가 준 갱신된 저장 장소. 받는 쪽이 목록 원소를 통째로 갈아 끼운다
            case saved(SavedPlace)
            case cancelled
            case sessionExpired
        }
    }

    @Dependency(\.placeClient) var placeClient

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce(core)
            .logged(as: Self.self)
    }

    private func core(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding:
            return updateInput(state: &state, action: action)
        case .saveTapped, .aliasSaved, .aliasSaveFailed:
            return saveAlias(state: &state, action: action)
        case .dismissed, .delegate:
            return raise(state: &state, action: action)
        }
    }

    private func updateInput(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .binding:
            state.errorMessage = nil
            return .none
        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    private func saveAlias(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .saveTapped:
            guard state.isSaveEnabled, !state.isSaving else { return .none }
            guard let placeID = Int(state.placeID) else {
                state.errorMessage = "저장한 장소가 아니에요"
                return .none
            }
            let alias = state.trimmedAlias
            state.isSaving = true
            state.errorMessage = nil
            return .run { [placeClient] send in
                do {
                    let saved = try await placeClient.updateAlias(placeID, alias)
                    await send(.aliasSaved(saved))
                } catch let error as PlaceError {
                    await send(.aliasSaveFailed(error))
                } catch {
                    await send(.aliasSaveFailed(.unknown))
                }
            }

        case let .aliasSaved(savedPlace):
            state.isSaving = false
            return .send(.delegate(.saved(savedPlace)))

        case let .aliasSaveFailed(error):
            state.isSaving = false
            switch error {
            case .unauthorized:
                // 전역 에러다. 문구를 띄우지 않고 상위가 처리한다
                state.errorMessage = nil
                return .send(.delegate(.sessionExpired))
            case .notFound:
                state.errorMessage = "저장한 장소가 아니에요"
            case .network, .alreadySaved, .unknown:
                state.errorMessage = "잠시 뒤 다시 시도해주세요"
            }
            return .none

        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }

    private func raise(state: inout State, action: Action) -> Effect<Action> {
        switch action {
        case .dismissed:
            return .send(.delegate(.cancelled))
        case .delegate:
            return .none
        default:
            assertionFailure("이 묶음이 안 받는 액션이다: \(action)")
            return .none
        }
    }
}
