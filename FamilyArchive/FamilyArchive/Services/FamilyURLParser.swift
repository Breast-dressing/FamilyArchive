//
//  FamilyURLParser.swift
//  FamilyArchive
//
//  Faithful Swift port of the URL parsing half of `services.py`:
//
//  * `detectURL(in:)` mirrors the clipboard handling of `add_family_flow`
//    (the reference code used the whole clipboard string, the specification
//    asks for the URL inside the clipboard content).
//  * `extractFamilyID(from:)` is a direct port of `_extract_family_id`.
//  * Short-link detection matches `_resolve_short_url` / `fetch_family_from_url`
//    (`c6.y.qq.com` and `c.y.qq.com` links are resolved first, see
//    `FamilyService.resolveShortLink`).
//

import Foundation

enum FamilyURLParser {
    /// Finds the first URL inside arbitrary clipboard text.
    static func detectURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) {
            let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
            if let match = detector.firstMatch(in: trimmed, options: [], range: range),
               let url = match.url {
                return url
            }
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        return nil
    }

    /// Port of `_extract_family_id`.
    ///
    /// * query parameters `family_id`, `familyId`, `fid` (first match wins)
    /// * otherwise the first `family_<id>` / `family/<id>` segment of the path
    ///
    /// Short-link resolution happens before this call (it needs the network).
    static func extractFamilyID(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {
            for name in ["family_id", "familyId", "fid"] {
                if let value = queryItems.first(where: { $0.name == name })?.value,
                   !value.isEmpty {
                    return value
                }
            }
        }

        let path = url.path
        guard !path.isEmpty else { return nil }
        guard let regex = try? NSRegularExpression(pattern: #"family[_/](\w+)"#) else {
            return nil
        }
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        guard let match = regex.firstMatch(in: path, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: path) else {
            return nil
        }
        let value = String(path[captureRange])
        return value.isEmpty ? nil : value
    }

    /// Port of the short-link check in `fetch_family_from_url`.
    static func needsShortLinkResolution(_ url: URL) -> Bool {
        let absolute = url.absoluteString
        return absolute.contains("c6.y.qq.com") || absolute.contains("c.y.qq.com")
    }
}
