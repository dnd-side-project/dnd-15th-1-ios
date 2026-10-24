import XCTest

/// `operation` 이 `expected` 를 던지는지 확인한다.
/// 아무것도 던지지 않거나 다른 에러를 던지면 호출한 줄에서 실패한다.
func assertThrows<E: Error & Equatable, T>(
    _ expected: E,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () async throws -> T
) async {
    do {
        _ = try await operation()
        XCTFail("Expected \(expected), but nothing was thrown", file: file, line: line)
    } catch let error as E {
        XCTAssertEqual(error, expected, file: file, line: line)
    } catch {
        XCTFail("Expected \(expected), got \(error)", file: file, line: line)
    }
}
