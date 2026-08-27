import CoreNetwork
import Foundation

struct TestEndpoint: APIEndpoint {
    var path: String
    var method: HTTPMethod
    var headers: [String: String]
    var queryItems: [URLQueryItem]
    var body: Data?

    init(
        path: String = "/api/users/me",
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
    }
}
