import Foundation

public struct NetworkConfiguration: Sendable {
    public let baseURL: URL
    public let timeout: TimeInterval
    public let jsonDecoder: JSONDecoder
    public let jsonEncoder: JSONEncoder

    public init(
        baseURL: URL,
        timeout: TimeInterval = 30,
        jsonDecoder: JSONDecoder = NetworkJSONCoding.makeDecoder(),
        jsonEncoder: JSONEncoder = NetworkJSONCoding.makeEncoder()
    ) {
        self.baseURL = baseURL
        self.timeout = timeout
        self.jsonDecoder = jsonDecoder
        self.jsonEncoder = jsonEncoder
    }
}
