import Foundation

struct BadgeSkin: Identifiable, Hashable {
    let id: String
    let sequence: Int
    let name: String
    let imageURL: String
    let isUnlocked: Bool
    let stateText: String
    let unlockDate: String
    let userCount: Int
    let unlockTask: String
    let backgroundColorHex: String

    var backgroundColor: String {
        backgroundColorHex.isEmpty ? "#fafafa" : backgroundColorHex
    }
}

enum BadgeSkinService {
    private static let medalID = "3069960"
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

    static func parse(html: String, sequence: Int) -> BadgeSkin? {
        guard let root = NodePortSupport.ssrJSON(from: html),
              NodePortSupport.int(root["code"]) == 0 else {
            return nil
        }

        let data = NodePortSupport.dictionary(root["data"])
        let skinInfo = NodePortSupport.dictionary(data["SkinInfo"])
        guard !skinInfo.isEmpty else { return nil }

        let levels = NodePortSupport.array(skinInfo["LevelList"])
        let level = levels.first ?? [:]
        let image = NodePortSupport.string(level["Pic"])
        guard !image.isEmpty else { return nil }

        let isUnlocked = NodePortSupport.int(level["State"]) == 2
            || NodePortSupport.int(skinInfo["UnlockedTs"]) > 0
        let unlockTs = NodePortSupport.int(skinInfo["UnlockedTs"])
        let guide = NodePortSupport.dictionary(level["LevelUnlockGuide"])
        let taskList = NodePortSupport.array(guide["TaskList"])
        let unlockTask = NodePortSupport.string(taskList.first?["Title"])

        return BadgeSkin(
            id: NodePortSupport.string(skinInfo["ID"]).isEmpty
                ? "\(medalID)-\(sequence)"
                : NodePortSupport.string(skinInfo["ID"]),
            sequence: sequence,
            name: NodePortSupport.string(skinInfo["Name"]).isEmpty
                ? "未命名"
                : NodePortSupport.string(skinInfo["Name"]),
            imageURL: image,
            isUnlocked: isUnlocked,
            stateText: isUnlocked ? "已解锁" : "未解锁",
            unlockDate: formatDate(unlockTs),
            userCount: NodePortSupport.int(skinInfo["UnlockedUserCnt"]),
            unlockTask: unlockTask,
            backgroundColorHex: NodePortSupport.string(level["BGColor"])
        )
    }

    static func fetchSkins(uin: String, sequences: [Int]) async -> [BadgeSkin] {
        guard !uin.isEmpty, !sequences.isEmpty else { return [] }

        var results: [BadgeSkin] = []
        await withTaskGroup(of: (Int, BadgeSkin?).self) { group in
            var iterator = sequences.makeIterator()
            var launched = 0
            let limit = min(6, sequences.count)

            while launched < limit, let seq = iterator.next() {
                group.addTask { (seq, await fetchSkin(uin: uin, sequence: seq)) }
                launched += 1
            }

            while let (_, skin) = await group.next() {
                if let skin {
                    results.append(skin)
                }
                if let seq = iterator.next() {
                    group.addTask { (seq, await fetchSkin(uin: uin, sequence: seq)) }
                }
            }
        }
        return results.sorted { $0.sequence < $1.sequence }
    }

    static func fetchSkin(uin: String, sequence: Int) async -> BadgeSkin? {
        var components = URLComponents(
            string: "https://i2.y.qq.com/n3/medal_collection/pages/medal_collection_v3/skin_detail.html"
        )
        components?.queryItems = [
            URLQueryItem(name: "_hidehd", value: "1"),
            URLQueryItem(name: "_fontscale", value: "1"),
            URLQueryItem(name: "skin_id", value: "\(medalID)-\(sequence)"),
            URLQueryItem(name: "enc_uin", value: uin)
        ]
        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://i2.y.qq.com/", forHTTPHeaderField: "Referer")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) else {
            return nil
        }
        return parse(html: html, sequence: sequence)
    }

    private static func formatDate(_ timestamp: Int) -> String {
        guard timestamp > 0 else { return "" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
