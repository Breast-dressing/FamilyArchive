import Foundation

struct LyricCardMaterial: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let isUnlocked: Bool
    let imageURL: String
}

struct LyricCard: Identifiable, Hashable {
    let id: String
    let songName: String
    let singerName: String
    let rarity: String
    let imageURL: String
    let backImageURL: String
    let frameURL: String
    let count: Int
    let isThreeD: Bool
    let firstUnlockDate: String
    let materials: [LyricCardMaterial]
    let serials: [String]
}

enum LyricCardService {
    static func parseHAR(data: Data) throws -> [LyricCard] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let log = root["log"] as? [String: Any],
              let entries = log["entries"] as? [[String: Any]],
              !entries.isEmpty else {
            throw LyricCardError.invalidHAR
        }

        var cards: [[String: Any]] = []
        var serials: [String: [String]] = [:]

        for entry in entries {
            let request = NodePortSupport.dictionary(entry["request"])
            let response = NodePortSupport.dictionary(entry["response"])
            let content = NodePortSupport.dictionary(response["content"])
            let url = NodePortSupport.string(request["url"])

            var text = NodePortSupport.string(content["text"])
            if NodePortSupport.string(content["encoding"]) == "base64",
               let decoded = Data(base64Encoded: text),
               let decodedText = String(data: decoded, encoding: .utf8) {
                text = decodedText
            }
            guard !text.isEmpty else { continue }

            if url.contains("singer_cards_collection.html")
                || text.contains("__ssrFirstPageData__") {
                if let ssr = NodePortSupport.ssrJSON(from: text),
                   let allCards = NodePortSupport.dictionary(ssr["allCardList"])["Cards"] as? [[String: Any]] {
                    cards = allCards
                }
            }

            if url.contains("_webcgikey=GetCardInfoByIDs"),
               url.contains("musics.fcg") {
                var requestIDs: [String] = []
                if let postText = NodePortSupport.string(
                    NodePortSupport.dictionary(request["postData"])["text"]
                ),
                let postData = postText.data(using: .utf8),
                let payload = try? JSONSerialization.jsonObject(with: postData) as? [String: Any] {
                    let requestZero = NodePortSupport.dictionary(payload["req_0"])
                    let param = NodePortSupport.dictionary(requestZero["param"])
                    requestIDs = (param["IDs"] as? [String])
                        ?? (param["IDList"] as? [String])
                        ?? []
                    if let single = param["ID"] as? String {
                        requestIDs.append(single)
                    }
                }

                if let responseData = text.data(using: .utf8),
                   let responseJSON = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                    let requestZero = NodePortSupport.dictionary(responseJSON["req_0"])
                    extractSerials(
                        from: requestZero["data"],
                        requestIDs: requestIDs,
                        into: &serials
                    )
                }
            }
        }

        guard !cards.isEmpty else {
            throw LyricCardError.noCards
        }

        return cards.compactMap { item in
            let cardID = NodePortSupport.string(item["ID"])
            let cardBack = NodePortSupport.dictionary(item["CardBackInfo"])
            let materials = NodePortSupport.array(
                NodePortSupport.dictionary(item["CardMaterialInfo"])["CardMaterials"]
            ).map { material in
                LyricCardMaterial(
                    name: NodePortSupport.string(material["MaterialName"]),
                    isUnlocked: NodePortSupport.bool(material["IsUnlock"]),
                    imageURL: normalizedURL(NodePortSupport.string(material["MaterialPic"]))
                )
            }

            let rarity = NodePortSupport.int(item["Rarity"])
            return LyricCard(
                id: cardID.isEmpty ? UUID().uuidString : cardID,
                songName: NodePortSupport.string(cardBack["SongName"]).isEmpty
                    ? NodePortSupport.string(item["Name"])
                    : NodePortSupport.string(cardBack["SongName"]),
                singerName: NodePortSupport.string(cardBack["SingerName"]).isEmpty
                    ? "未知"
                    : NodePortSupport.string(cardBack["SingerName"]),
                rarity: rarity == 6 ? "SSR" : (rarity == 5 ? "SR" : "R"),
                imageURL: normalizedURL(NodePortSupport.string(item["FgPic"])),
                backImageURL: normalizedURL(NodePortSupport.string(cardBack["Pic"])),
                frameURL: normalizedURL(NodePortSupport.string(item["Frame"])),
                count: NodePortSupport.int(item["Num"]),
                isThreeD: NodePortSupport.bool(
                    NodePortSupport.dictionary(item["ThreeDInfo"])["IsThreeD"]
                ),
                firstUnlockDate: formatDate(NodePortSupport.int(item["FirstUnlockTs"])),
                materials: materials,
                serials: serials[cardID] ?? []
            )
        }
    }

    private static func extractSerials(
        from value: Any?,
        requestIDs: [String],
        into serials: inout [String: [String]]
    ) {
        if let array = value as? [Any] {
            for item in array {
                extractSerials(from: item, requestIDs: requestIDs, into: &serials)
            }
            return
        }

        guard let object = value as? [String: Any] else { return }
        if let list = object["SerialNumList"] as? [String], !list.isEmpty {
            let cardID = NodePortSupport.string(object["ID"])
            let fallbackID = NodePortSupport.string(object["CardID"])
            let resolved = !cardID.isEmpty
                ? cardID
                : (!fallbackID.isEmpty ? fallbackID : (requestIDs.count == 1 ? requestIDs[0] : ""))
            if !resolved.isEmpty {
                serials[resolved] = list
            }
        }
        for child in object.values {
            extractSerials(from: child, requestIDs: requestIDs, into: &serials)
        }
    }

    private static func normalizedURL(_ value: String) -> String {
        value.replacingOccurrences(of: "http://", with: "https://")
    }

    private static func formatDate(_ timestamp: Int) -> String {
        guard timestamp > 0 else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(timestamp)))
    }
}

enum LyricCardError: LocalizedError {
    case invalidHAR
    case noCards

    var errorDescription: String? {
        switch self {
        case .invalidHAR: return "不是有效的 HAR 文件。"
        case .noCards: return "HAR 中未找到卡池数据，请确保抓包包含页面加载请求。"
        }
    }
}
