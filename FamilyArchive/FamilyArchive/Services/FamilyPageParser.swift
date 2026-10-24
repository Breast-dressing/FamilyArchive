//
//  FamilyPageParser.swift
//  FamilyArchive
//
//  Port of the HTML/SSR helpers in `services.py`:
//  `_extract_ssr_data`, `_parse_family_info_from_ssr`, and the `family_id`
//  fallback used by `fetch_family_from_url`.
//

import Foundation

enum FamilyPageParser {
    struct SSRFamilyInfo {
        let name: String
        let announcement: String
        let avatarURL: String
        let honor: String
        let rank: String
        let members: String
        let pkWins: String
    }

    /// Port of `_extract_ssr_data`.
    ///
    /// Finds `window.__ssrFirstPageData__ = "<escaped json>"` and applies the
    /// exact same unescaping order as the Python implementation.
    static func extractSSRJSON(_ html: String) -> [String: Any]? {
        let pattern = #"window\.__ssrFirstPageData__\s*=\s*"((?:[^"\\]|\\.)*)""#
        guard let raw = firstCapture(in: html, pattern: pattern) else { return nil }

        var decoded = raw
        decoded = decoded.replacingOccurrences(of: "\\\"", with: "\"")
        decoded = decoded.replacingOccurrences(of: "\\\\", with: "\\")
        decoded = decoded.replacingOccurrences(of: "\\u002F", with: "/")
        decoded = decoded.replacingOccurrences(of: "\\u0026", with: "&")

        guard let data = decoded.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Port of `_parse_family_info_from_ssr`.
    static func parseFamilyInfo(_ json: [String: Any]) -> SSRFamilyInfo? {
        var candidates: [[String: Any]] = []
        if let requestZero = json["req_0"] as? [String: Any],
           let data = requestZero["data"] as? [String: Any] {
            candidates.append(data)
        }
        if let data = json["data"] as? [String: Any] {
            candidates.append(data)
        }

        for candidate in candidates {
            guard candidate["Name"] != nil || candidate["Avatar"] != nil else { continue }
            let name = JSONSupport.string(candidate["Name"])
            let announcement = JSONSupport.string(candidate["Announcement"])
            let avatar = JSONSupport.normalizeAvatarURL(JSONSupport.string(candidate["Avatar"]))
            var honor = ""
            var rank = ""
            var members = ""
            var pkWins = ""
            for item in (candidate["DetailItemList"] as? [[String: Any]]) ?? [] {
                let title = JSONSupport.string(item["Title"])
                let desc = JSONSupport.string(item["Desc"])
                if desc.contains("总荣誉值") {
                    honor = title
                } else if desc.contains("周排名") {
                    rank = title
                } else if desc.contains("成员") {
                    members = title
                } else if desc.contains("PK胜场") {
                    pkWins = title
                }
            }
            return SSRFamilyInfo(
                name: name,
                announcement: announcement,
                avatarURL: avatar,
                honor: honor,
                rank: rank,
                members: members,
                pkWins: pkWins
            )
        }
        return nil
    }

    /// Port of the fallback chain used by `fetch_family_from_url` when the URL
    /// itself does not contain a family id:
    /// `query.family_id`, then `data.MedalID`.
    static func familyIDFromSSR(_ json: [String: Any]) -> String? {
        if let query = json["query"] as? [String: Any] {
            let value = JSONSupport.string(query["family_id"])
            if !value.isEmpty {
                return value
            }
        }
        if let data = json["data"] as? [String: Any] {
            let medalID = JSONSupport.string(data["MedalID"])
            if !medalID.isEmpty {
                return medalID
            }
        }
        return nil
    }

    /// Returns the first capture group of `pattern` in `text`.
    /// Used both for the SSR payload and for the short-link `family_id=` body scan.
    static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators]
        ) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
