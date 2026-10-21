import CoreStorage
import Foundation

/// 실제 키체인처럼 한 번에 하나씩 처리하는 가짜 키체인. 읽기·저장을 붙잡거나 읽기·저장·삭제를 실패시킬 수 있다.
/// `StubKeychainStorage` 는 잠금 없는 클래스라 순서 테스트에 쓰지 않는다.
actor SerialKeychainStorage: KeychainStorage {
    private var storage: [String: Data] = [:]
    private(set) var loadCount = 0
    private var loadError: Error?
    private var saveError: Error?
    private var deleteError: Error?
    private var isHoldingLoads = false
    private var heldLoads: [CheckedContinuation<Void, Never>] = []
    private var onLoadArrival: (@Sendable () -> Void)?
    private var isHoldingSaves = false
    private var heldSaves: [CheckedContinuation<Void, Never>] = []
    private var onSaveArrival: (@Sendable () -> Void)?

    func setLoadError(_ error: Error?) {
        loadError = error
    }

    func setSaveError(_ error: Error?) {
        saveError = error
    }

    func setDeleteError(_ error: Error?) {
        deleteError = error
    }

    /// 이 뒤의 읽기는 `releaseLoads()` 를 부를 때까지 끝나지 않는다. 읽기가 닿을 때마다 `onArrival` 을 부른다
    func holdLoads(onArrival: @escaping @Sendable () -> Void) {
        isHoldingLoads = true
        onLoadArrival = onArrival
    }

    func releaseLoads() {
        isHoldingLoads = false
        let held = heldLoads
        heldLoads.removeAll()
        for continuation in held {
            continuation.resume()
        }
    }

    /// 이 뒤의 저장은 `releaseSaves()` 를 부를 때까지 끝나지 않는다. 저장이 닿을 때마다 `onArrival` 을 부른다
    func holdSaves(onArrival: @escaping @Sendable () -> Void) {
        isHoldingSaves = true
        onSaveArrival = onArrival
    }

    func releaseSaves() {
        isHoldingSaves = false
        let held = heldSaves
        heldSaves.removeAll()
        for continuation in held {
            continuation.resume()
        }
    }

    func save<T: Codable & Sendable>(_ value: T, forKey key: String) async throws {
        onSaveArrival?()
        if isHoldingSaves {
            await withCheckedContinuation { heldSaves.append($0) }
        }
        if let saveError {
            throw saveError
        }
        storage[key] = try JSONEncoder().encode(value)
    }

    func get<T: Codable & Sendable>(forKey key: String) async throws -> T? {
        loadCount += 1
        // 읽기를 시작한 때의 값을 돌려준다. 붙잡힌 사이 다른 쓰기가 끝나도 옛 값을 읽은 것으로 본다
        let snapshot = storage[key]
        onLoadArrival?()
        if isHoldingLoads {
            await withCheckedContinuation { heldLoads.append($0) }
        }
        if let loadError {
            throw loadError
        }
        guard let snapshot else { return nil }
        return try JSONDecoder().decode(T.self, from: snapshot)
    }

    func update<T: Codable & Sendable>(
        forKey key: String,
        _ transform: @Sendable (T) -> T
    ) async throws {
        guard let data = storage[key] else { return }
        let current = try JSONDecoder().decode(T.self, from: data)
        storage[key] = try JSONEncoder().encode(transform(current))
    }

    func delete(forKey key: String) async throws {
        if let deleteError {
            throw deleteError
        }
        storage.removeValue(forKey: key)
    }

    func deleteAll() async throws {
        storage.removeAll()
    }
}
