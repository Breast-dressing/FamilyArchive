import Foundation

/// Shared helpers for the three ported Node parsing pipelines.
enum NodePortSupport {
    static func ssrJSON(from html: String) -> [String: Any]? {
        let pattern = #"window\.__ssrFirstPageData__\s*=\s*("(?:[^"\\]|\\.)*")"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: html,
                range: NSRange(html.startIndex..., in: html)
              ),
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let quoted = String(html[range])
        guard let quotedData = quoted.data(using: .utf8),
              let jsonString = try? JSONSerialization.jsonObject(
                with: quotedData,
                options: [.fragmentsAllowed]
              ) as? String,
              let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let dictionary = object as? [String: Any] else {
            return nil
        }
        return dictionary
    }

    static func dictionary(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }

    static func array(_ value: Any?) -> [[String: Any]] {
        value as? [[String: Any]] ?? []
    }

    static func string(_ value: Any?) -> String {
        if let text = value as? String { return text }
        if let number = value as? NSNumber { return number.stringValue }
        return ""
    }

    static func int(_ value: Any?) -> Int {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber { return number.intValue }
        if let text = value as? String { return Int(text) ?? 0 }
        return 0
    }

    static func double(_ value: Any?) -> Double {
        if let number = value as? Double { return number }
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) ?? 0 }
        return 0
    }

    static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool { return value }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }
}
