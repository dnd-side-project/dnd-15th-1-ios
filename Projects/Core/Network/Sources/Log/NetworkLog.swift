import Foundation
import SharedLogger

enum NetworkLog {
    static func request(_ request: URLRequest) {
        let method = request.httpMethod ?? "NIL"
        let url = sanitizedURLString(request.url)
        var message = "[Network] [Request] → \(method) \(url)"

        #if DEBUG
        if let body = request.httpBody, let bodyText = String(data: body, encoding: .utf8) {
            message += "\nBody:\n\(formattedBody(bodyText))"
        }
        #endif

        Logger.shared.info(message, category: .network, includeCallSite: false)
    }

    static func response(
        statusCode: Int,
        url: URL?,
        data: Data,
        durationMs: Int
    ) {
        let target = sanitizedURLString(url)
        var message = "[Network] [Response] ← \(statusCode) \(target) (\(durationMs)ms, \(data.count)B)"

        #if DEBUG
        if let bodyText = String(data: data, encoding: .utf8), bodyText.isEmpty == false {
            message += "\nBody:\n\(formattedBody(bodyText))"
        }
        #endif

        if (200...299).contains(statusCode) {
            Logger.shared.info(message, category: .network, includeCallSite: false)
        } else {
            Logger.shared.warning(message, category: .network, includeCallSite: false)
        }
    }

    static func error(_ error: Error, url: URL?) {
        Logger.shared.error(
            "[Network] [Error] ✕ \(sanitizedURLString(url)) \(error.localizedDescription)",
            category: .network,
            includeCallSite: false
        )
    }

    static func sanitizedURLString(_ url: URL?) -> String {
        guard let url else { return "nil" }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return pathOnly(from: url)
        }
        components.scheme = nil
        components.host = nil
        components.port = nil
        components.user = nil
        components.password = nil
        components.query = nil
        components.fragment = nil
        let path = components.percentEncodedPath
        if path.isEmpty == false {
            return path
        }
        return pathOnly(from: url)
    }

    private static func pathOnly(from url: URL) -> String {
        let path = url.path
        return path.isEmpty ? "/" : path
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
        output = redactBearerTokens(in: output)
        output = redactJSONTokenFields(in: output)
        output = redactFormTokenFields(in: output)
        return output
    }

    private static func redactBearerTokens(in text: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"Bearer\s+[A-Za-z0-9\-._~+/]+=*"#,
            options: [.caseInsensitive]
        ) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: "Bearer [REDACTED]"
        )
    }

    private static func redactJSONTokenFields(in text: String) -> String {
        let keys = [
            "accessToken",
            "refreshToken",
            "Authorization",
            "identityToken",
            "access_token",
            "refresh_token",
            "id_token"
        ].joined(separator: "|")
        let pattern = "\"(\(keys))\"\\s*:\\s*\"[^\"]*\""
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: #""$1" : "[REDACTED]""#
        )
    }

    private static func redactFormTokenFields(in text: String) -> String {
        let keys = [
            "access_token",
            "refresh_token",
            "id_token",
            "accessToken",
            "refreshToken",
            "identityToken"
        ].joined(separator: "|")

        var output = text
        let quotedPattern = "(?i)\\b(\(keys))=\"[^\"&\\s]*\""
        if let regex = try? NSRegularExpression(pattern: quotedPattern) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: #"$1=[REDACTED]"#
            )
        }

        let barePattern = "(?i)\\b(\(keys))=([^&\\s]+)"
        if let regex = try? NSRegularExpression(pattern: barePattern) {
            let range = NSRange(output.startIndex..<output.endIndex, in: output)
            output = regex.stringByReplacingMatches(
                in: output,
                options: [],
                range: range,
                withTemplate: #"$1=[REDACTED]"#
            )
        }
        return output
    }
}
