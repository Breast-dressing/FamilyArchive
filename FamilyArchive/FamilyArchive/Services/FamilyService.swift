//
//  FamilyService.swift
//  FamilyArchive
//
//  Port of `fetch_family_from_url` and `_resolve_short_url` from `services.py`.
//
//  The reference implementation fetches the family web page first (to read the
//  SSR family info and, if needed, the family id) and then talks to the family
//  APIs. The CORS proxies used by the Python client are not needed from a
//  native app, so requests go directly to the same endpoints.
//

import Foundation

struct ParsedMember: Sendable, Hashable {
    let memberID: String
    let name: String
    let avatarURL: String
}

struct ParsedFamily: Sendable {
    let url: String
    let familyID: String
    let name: String
    /// True when `name` came from the family page / API rather than from a
    /// local fallback, so an existing stored name is never overwritten by a
    /// placeholder.
    let nameIsResolved: Bool
    let avatarURL: String
    let members: [ParsedMember]
}

enum FamilyService {
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    /// Resolves a family URL exactly as `fetch_family_from_url` does and returns
    /// everything the app persists. Network failures degrade gracefully: the
    /// family is still returned (with a derived name and an empty member list).
    static func loadFamily(from url: URL) async -> ParsedFamily {
        var resolvedURL = url
        if FamilyURLParser.needsShortLinkResolution(url) {
            if let resolved = await resolveShortLink(url) {
                resolvedURL = resolved
            }
        }

        var familyID = FamilyURLParser.extractFamilyID(from: resolvedURL) ?? ""
        var name = ""
        var avatarURL = ""

        if let html = await fetchHTML(resolvedURL),
           let ssr = FamilyPageParser.extractSSRJSON(html) {
            if let info = FamilyPageParser.parseFamilyInfo(ssr) {
                name = info.name
                avatarURL = info.avatarURL
            }
            if familyID.isEmpty,
               let fallbackID = FamilyPageParser.familyIDFromSSR(ssr),
               !fallbackID.isEmpty {
                familyID = fallbackID
            }
        }

        var members: [ParsedMember] = []
        if !familyID.isEmpty {
            members = await QQMusicAPI.fetchMembers(familyID: familyID)
            if name.isEmpty || avatarURL.isEmpty {
                if let info = await QQMusicAPI.fetchFamilyInfo(familyID: familyID) {
                    if name.isEmpty { name = info.name }
                    if avatarURL.isEmpty { avatarURL = info.avatarURL }
                }
            }
        }

        let nameIsResolved = !name.isEmpty
        let displayName = name.isEmpty ? fallbackName(familyID: familyID, url: resolvedURL) : name
        return ParsedFamily(
            url: url.absoluteString,
            familyID: familyID,
            name: displayName,
            nameIsResolved: nameIsResolved,
            avatarURL: avatarURL,
            members: members
        )
    }

    // MARK: - Short links

    /// Port of `_resolve_short_url`.
    private static func resolveShortLink(_ url: URL) async -> URL? {
        guard let (data, response) = try? await URLSession.shared.data(
            for: browserRequest(for: url, timeout: 10)
        ) else {
            return nil
        }
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            return nil
        }

        if let finalURL = response.url,
           finalURL.absoluteString != url.absoluteString,
           finalURL.absoluteString.contains("family_id") {
            return finalURL
        }

        guard let body = String(data: data, encoding: .utf8),
              body.contains("family_id=") else {
            return nil
        }
        guard let value = FamilyPageParser.firstCapture(
            in: body,
            pattern: #"family_id=([^&"'<\s]+)"#
        ) else {
            return nil
        }
        return URL(string: "https://i2.y.qq.com/?family_id=\(value)")
    }

    // MARK: - HTML

    /// Port of the direct HTML request (with the same cache-busting `_t`
    /// parameter) from `_fetch_html`.
    private static func fetchHTML(_ url: URL) async -> String? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        var queryItems = components.queryItems ?? []
        queryItems.append(
            URLQueryItem(
                name: "_t",
                value: String(Int(Date().timeIntervalSince1970 * 1000))
            )
        )
        components.queryItems = queryItems
        guard let noCacheURL = components.url else { return nil }

        guard let (data, response) = try? await URLSession.shared.data(
            for: browserRequest(for: noCacheURL, timeout: 15)
        ) else {
            return nil
        }
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    private static func browserRequest(for url: URL, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("https://y.qq.com/", forHTTPHeaderField: "Referer")
        request.setValue("https://y.qq.com", forHTTPHeaderField: "Origin")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        return request
    }

    // MARK: - Naming

    private static func fallbackName(familyID: String, url: URL) -> String {
        if !familyID.isEmpty {
            return "Family \(familyID)"
        }
        if let host = url.host, !host.isEmpty {
            return host
        }
        return "Family"
    }
}
