//
//  JSONSupport.swift
//  FamilyArchive
//

import Foundation

/// Small helpers for the loosely-typed JSON returned by the QQ Music APIs and
/// embedded in QQ Music family web pages.
enum JSONSupport {
    /// Returns a string for a JSON value, bridging `NSNumber` values as well.
    static func string(_ value: Any?) -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        return ""
    }

    /// Port of the reference `_normalize_avatar_url` helper.
    static func normalizeAvatarURL(_ url: String) -> String {
        var value = url.replacingOccurrences(of: "\\/", with: "/")
        value = value.replacingOccurrences(of: "&amp;", with: "&")
        if value.hasPrefix("http://") {
            value = "https://" + String(value.dropFirst("http://".count))
        }
        return value
    }
}
