import Foundation
import SharedLogger

enum NetworkLog {
    static func request(_ request: URLRequest) {
        let method = request.httpMethod ?? "NIL"
        let url = sanitizedURLString(request.url)
        var message = "→ \(method) \(url)"

        #if DEBUG
        if let body = request.httpBody, let bodyText = String(data: body, encoding: .utf8) {
            message += "\nBody:\n\(formattedBody(bodyText))"
        }
        #endif

        Logger.shared.info(message, category: .network)
    }

    static func response(
        statusCode: Int,
        url: URL?,
        data: Data,
        durationMs: Int
    ) {
        let target = sanitizedURLString(url)
        var message = "← \(statusCode) \(target) (\(durationMs)ms, \(data.count)B)"

        #if DEBUG
        if let bodyText = String(data: data, encoding: .utf8), bodyText.isEmpty == false {
            message += "\nBody:\n\(formattedBody(bodyText))"
        }
        #endif

        if (200...299).contains(statusCode) {
            Logger.shared.info(message, category: .network)
        } else {
            Logger.shared.warning(message, category: .network)
        }
    }

    static func error(_ error: Error, url: URL?) {
        Logger.shared.error(
            "✕ \(sanitizedURLString(url)) \(error.localizedDescription)",
            category: .network
        )
    }

    static func sanitizedURLString(_ url: URL?) -> String {
        guard let url else { return "nil" }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url.absoluteString
        }
        components.query = nil
        components.fragment = nil
        return components.string ?? url.absoluteString
    }

    static func formattedBody(_ text: String) -> String {
        redact(prettyPrintedJSON(text) ?? text)
    }

    static func prettyPrintedJSON(_ text: String) -> String? {
        guard
            let data = text.data(using: .utf8),
            let object = try? JSONSerialization.jsonObject(with: data),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let pretty = String(data: prettyData, encoding: .utf8)
        else {
            return nil
        }
        return pretty
    }

    static func redact(_ text: String) -> String {
        var output = text

        if let bearerRegex = try? NSRegularExpression(
            pattern: #"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = bearerRegex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: "Bearer [REDACTED]"
            )
        }

        if let fieldRegex = try? NSRegularExpression(
            pattern: #""(accessToken|refreshToken|Authorization|identityToken)"\s*:\s*"[^"]*""#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = fieldRegex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: #""$1" : "[REDACTED]""#
            )
        }

        return output
    }
}
