//
//  QQMusicAPI.swift
//  FamilyArchive
//
//  Port of the QQ Music family endpoints used by `services.py`:
//
//  * `sign()`                 -> `sign`
//  * `_qq_api_post`           -> `post(webcgikey:payload:)`
//  * `_fetch_members_from_api`-> `fetchMembers(familyID:)`
//  * `_fetch_family_info_from_api` -> `fetchFamilyInfo(familyID:)`
//  * `_parse_member_item`     -> `parseMember`
//
//  Only the fields the app actually stores (id, display name, avatar) are
//  extracted; medals / fan badges / honor totals are not part of this build.
//

import CryptoKit
import Foundation

struct QQFamilyInfo: Sendable {
    let name: String
    let announcement: String
    let avatarURL: String
    let honor: String
    let rank: String
    let members: String
    let pkWins: String
}

enum QQMusicAPI {
    private static let apiURL = "https://u6.y.qq.com/cgi-bin/musics.fcg"

    private static let partOneIndexes = [23, 14, 6, 36, 16, 7, 19]
    private static let partTwoIndexes = [16, 1, 32, 12, 19, 27, 8, 5]
    private static let scrambleValues: [UInt8] = [
        89, 39, 179, 150, 218, 82, 58, 252, 177, 52,
        186, 123, 120, 64, 242, 133, 143, 161, 121, 179
    ]

    private static let headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Referer": "https://y.qq.com/",
        "Origin": "https://y.qq.com",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "zh-CN,zh;q=0.9",
        "Content-Type": "application/json;charset=UTF-8"
    ]

    // MARK: - Signing

    /// Port of `sign()` from `services.py`.
    static func sign(_ payload: String) -> String {
        let digest = Insecure.SHA1.hash(data: Data(payload.utf8))
        let hex = digest.map { String(format: "%02X", $0) }.joined()
        let characters = Array(hex)

        var first = ""
        for index in partOneIndexes {
            first.append(characters[index])
        }

        var second = ""
        for index in partTwoIndexes {
            second.append(characters[index])
        }

        var scrambled = [UInt8](repeating: 0, count: 20)
        for index in 0..<20 {
            let start = hex.index(hex.startIndex, offsetBy: index * 2)
            let end = hex.index(start, offsetBy: 2)
            let byte = UInt8(hex[start..<end], radix: 16) ?? 0
            scrambled[index] = scrambleValues[index] ^ byte
        }

        let base64 = Data(scrambled).base64EncodedString()
        let cleaned = base64.filter { character in
            character != "/" && character != "+" && character != "=" && character != "\\"
        }
        return ("zzc" + first + cleaned + second).lowercased()
    }

    // MARK: - Transport

    /// Port of `_qq_api_post`.
    private static func post(webcgikey: String, payload: [String: Any]) async -> [String: Any]? {
        guard let bodyData = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ), let body = String(data: bodyData, encoding: .utf8) else {
            return nil
        }

        let signature = sign(body)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        guard let url = URL(string: "\(apiURL)?_webcgikey=\(webcgikey)&_=\(timestamp)&sign=\(signature)") else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func medalID(from familyID: String) -> String {
        if let first = familyID.split(separator: "_").first {
            return String(first)
        }
        return familyID
    }

    // MARK: - Members

    /// Port of `_fetch_members_from_api` (GetRankTabDetail + BatchGetRankItem).
    static func fetchMembers(familyID: String) async -> [ParsedMember] {
        let medal = medalID(from: familyID)

        var param: [String: Any] = [:]
        param["MedalID"] = medal
        param["TabID"] = 5
        param["FirstPageSize"] = 20
        param["From"] = 2
        param["Target"] = familyID

        var requestZero: [String: Any] = [:]
        requestZero["module"] = "music.medalHall.MedalRankListSrv"
        requestZero["method"] = "GetRankTabDetail"
        requestZero["param"] = param

        var payload: [String: Any] = [:]
        payload["comm"] = [String: Any]()
        payload["req_0"] = requestZero

        guard let response = await post(webcgikey: "GetRankTabDetail", payload: payload),
              let request = response["req_0"] as? [String: Any],
              (request["code"] as? Int) == 0,
              let data = request["data"] as? [String: Any] else {
            return []
        }

        let detail = data["Detail"] as? [String: Any] ?? [:]
        let firstPage = detail["FirstPageInfo"] as? [[String: Any]] ?? []
        let itemList = detail["ItemList"] as? [[String: Any]] ?? []

        var members: [String: ParsedMember] = [:]
        var firstPageIDs = Set<String>()

        for item in firstPage {
            if let member = parseMember(item) {
                members[member.memberID] = member
                firstPageIDs.insert(member.memberID)
            }
        }

        var remainingItems: [[String: Any]] = []
        for item in itemList {
            let itemID = JSONSupport.string(item["ItemID"])
            guard !itemID.isEmpty, !firstPageIDs.contains(itemID) else { continue }
            var remaining: [String: Any] = [:]
            remaining["ItemID"] = itemID
            remaining["Value"] = JSONSupport.string(item["Value"])
            remainingItems.append(remaining)
        }

        if !remainingItems.isEmpty {
            var comm: [String: Any] = [:]
            comm["g_tk"] = 5381
            comm["uin"] = ""
            comm["format"] = "json"
            comm["inCharset"] = "utf-8"
            comm["outCharset"] = "utf-8"
            comm["notice"] = 0
            comm["platform"] = "h5"
            comm["needNewCode"] = 1

            var batchParam: [String: Any] = [:]
            batchParam["MedalID"] = medal
            batchParam["TabID"] = 5
            batchParam["Items"] = remainingItems

            var batchRequestZero: [String: Any] = [:]
            batchRequestZero["module"] = "music.medalHall.MedalRankListSrv"
            batchRequestZero["method"] = "BatchGetRankItem"
            batchRequestZero["param"] = batchParam

            var batchPayload: [String: Any] = [:]
            batchPayload["comm"] = comm
            batchPayload["req_0"] = batchRequestZero

            if let batchResponse = await post(webcgikey: "BatchGetRankItem", payload: batchPayload),
               let batchRequest = batchResponse["req_0"] as? [String: Any],
               (batchRequest["code"] as? Int) == 0,
               let batchData = batchRequest["data"] as? [String: Any],
               let itemMap = batchData["ItemMap"] as? [String: Any] {
                for (_, value) in itemMap {
                    if let item = value as? [String: Any], let member = parseMember(item) {
                        members[member.memberID] = member
                    }
                }
            }
        }

        // The reference implementation always folds the item list back in as a
        // fallback for entries that were not returned by either detail call.
        for item in itemList {
            if let member = parseMember(item) {
                members[member.memberID] = member
            }
        }

        return members.values.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - Family info

    /// Port of `_fetch_family_info_from_api`.
    static func fetchFamilyInfo(familyID: String) async -> QQFamilyInfo? {
        var param: [String: Any] = [:]
        param["FamilyID"] = familyID
        param["MedalID"] = medalID(from: familyID)

        var requestZero: [String: Any] = [:]
        requestZero["module"] = "music.medalHall.MedalRankListSrv"
        requestZero["method"] = "GetFamilyHomepageHeader"
        requestZero["param"] = param

        var payload: [String: Any] = [:]
        payload["comm"] = [String: Any]()
        payload["req_0"] = requestZero

        guard let response = await post(webcgikey: "GetFamilyHomepageHeader", payload: payload),
              let request = response["req_0"] as? [String: Any],
              (request["code"] as? Int) == 0,
              let data = request["data"] as? [String: Any] else {
            return nil
        }

        let name = JSONSupport.string(data["Name"])
        let announcement = JSONSupport.string(data["Announcement"])
        let avatar = JSONSupport.normalizeAvatarURL(JSONSupport.string(data["Avatar"]))
        var honor = ""
        var rank = ""
        var members = ""
        var pkWins = ""
        for item in (data["DetailItemList"] as? [[String: Any]]) ?? [] {
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
        guard !name.isEmpty || !avatar.isEmpty || !announcement.isEmpty
                || !honor.isEmpty || !rank.isEmpty || !members.isEmpty || !pkWins.isEmpty else {
            return nil
        }
        return QQFamilyInfo(
            name: name,
            announcement: announcement,
            avatarURL: avatar,
            honor: honor,
            rank: rank,
            members: members,
            pkWins: pkWins
        )
    }

    // MARK: - Item parsing

    /// Port of `_clean_medal_level`.
    static func cleanMedalLevel(_ value: String) -> String {
        guard !value.isEmpty else { return "" }
        guard let regex = try? NSRegularExpression(pattern: "V\\d+") else {
            return value
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        guard let match = regex.firstMatch(in: value, options: [], range: range),
              let matchRange = Range(match.range, in: value) else {
            return value
        }
        return String(value[matchRange])
    }

    /// Port of `_parse_member_item` (medal, nameplate and API honor included).
    static func parseMember(_ item: [String: Any]) -> ParsedMember? {
        let itemID = JSONSupport.string(item["ItemID"])
        let title = JSONSupport.string(item["Title"])
        guard !title.isEmpty else { return nil }

        let memberID = itemID.isEmpty ? "name_" + title : itemID
        let avatar = JSONSupport.normalizeAvatarURL(JSONSupport.string(item["Pic"]))

        var medal = ""
        var nameplate = ""
        for wear in (item["WearList"] as? [[String: Any]]) ?? [] {
            let wearTitle = JSONSupport.string(wear["Title"])
            if wearTitle.contains("V") {
                medal = cleanMedalLevel(wearTitle)
            }
            if let segment = wear["Segment"] as? [String: Any],
               let contents = segment["Contents"] as? [[String: Any]] {
                for content in contents {
                    let value = JSONSupport.string(content["Content"])
                    if value.hasPrefix("NO.") {
                        nameplate = value
                    }
                }
            }
        }

        var honor = ""
        for descItem in (item["DescList"] as? [[String: Any]]) ?? [] {
            let desc = JSONSupport.string(descItem["Desc"])
            if desc.contains("荣誉值"),
               let regex = try? NSRegularExpression(pattern: "(\\d+)"),
               let match = regex.firstMatch(
                    in: desc,
                    options: [],
                    range: NSRange(desc.startIndex..<desc.endIndex, in: desc)
               ),
               let range = Range(match.range(at: 1), in: desc) {
                honor = String(desc[range])
                break
            }
        }

        return ParsedMember(
            memberID: memberID,
            name: title,
            avatarURL: avatar,
            medalLevel: medal,
            nameplate: nameplate,
            apiHonor: Int(honor) ?? 0
        )
    }
}
