import Foundation

struct MedalItem: Identifiable, Hashable {
    let id: String
    let name: String
    let imageURL: String
    let level: Int
    let createTime: String
    let isObtained: Bool
}

struct MedalModule: Identifiable, Hashable {
    let id: String
    let name: String
    let scheme: String
    let hasNext: Bool
    let medals: [MedalItem]
}

struct MedalTab: Identifiable, Hashable {
    let id: Int
    let title: String
    let modules: [MedalModule]
}

struct MedalHallSnapshot {
    let encUin: String
    let tabs: [MedalTab]
}

enum MedalHallService {
    private static let apiURL = "https://u6.y.qq.com/cgi-bin/musics.fcg"
    private static let headers: [String: String] = [
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        "Referer": "https://y.qq.com/",
        "Origin": "https://y.qq.com",
        "Accept": "application/json, text/plain, */*",
        "Content-Type": "application/json;charset=UTF-8"
    ]

    static func load(urlString: String) async throws -> MedalHallSnapshot {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            throw MedalHallError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(headers["User-Agent"], forHTTPHeaderField: "User-Agent")
        request.setValue("zh-CN,zh;q=0.9", forHTTPHeaderField: "Accept-Language")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8),
              let root = NodePortSupport.ssrJSON(from: html) else {
            throw MedalHallError.invalidResponse
        }

        let dataObject = NodePortSupport.dictionary(root["data"])
        let query = NodePortSupport.dictionary(root["query"])
        let encUin = NodePortSupport.string(dataObject["EncUin"]).isEmpty
            ? NodePortSupport.string(query["enc_uin"])
            : NodePortSupport.string(dataObject["EncUin"])
        let currentID = NodePortSupport.int(dataObject["CurrTabID"])
        let tabList = NodePortSupport.array(dataObject["TabList"])
        let currentModules = parseModules(
            NodePortSupport.dictionary(dataObject["TabInfo"])["ModuleList"]
        )

        guard !tabList.isEmpty else {
            throw MedalHallError.noTabs
        }

        var tabs: [MedalTab] = []
        for tab in tabList {
            let tabID = NodePortSupport.int(tab["ID"])
            let title = NodePortSupport.string(tab["Title"]).isEmpty
                ? "勋章 \(tabID)"
                : NodePortSupport.string(tab["Title"])

            let modules: [MedalModule]
            if tabID == currentID {
                modules = currentModules
            } else {
                modules = await fetchModules(
                    encUin: encUin,
                    tabID: tabID
                )
            }
            tabs.append(MedalTab(id: tabID, title: title, modules: modules))
        }

        return MedalHallSnapshot(encUin: encUin, tabs: tabs)
    }

    static func parseModules(_ value: Any?) -> [MedalModule] {
        NodePortSupport.array(value).compactMap { module in
            let moduleID = NodePortSupport.string(module["ModuleID"])
            let name = NodePortSupport.string(module["ModuleName"])
            let medals = parseMedals(module["MedalList"])
            let cards = parseMedals(module["CardList"])
            let items = cards.isEmpty ? medals : cards
            guard !moduleID.isEmpty || !items.isEmpty else { return nil }

            let style = NodePortSupport.dictionary(module["Style"])
            return MedalModule(
                id: moduleID.isEmpty ? "module-\(name)" : moduleID,
                name: name.isEmpty ? "勋章模块" : name,
                scheme: NodePortSupport.string(style["Scheme"]),
                hasNext: NodePortSupport.bool(style["HasNext"]),
                medals: items
            )
        }
    }

    static func parseMedals(_ value: Any?) -> [MedalItem] {
        NodePortSupport.array(value).compactMap { item in
            let level = NodePortSupport.int(item["Level"])
            let medalID = NodePortSupport.string(item["MedalID"])
            let name = NodePortSupport.string(item["Name"])
            guard !medalID.isEmpty || !name.isEmpty else { return nil }

            return MedalItem(
                id: medalID.isEmpty ? "medal-\(name)" : medalID,
                name: name.isEmpty ? "未命名" : name,
                imageURL: NodePortSupport.string(item["PicURL"]),
                level: level,
                createTime: NodePortSupport.string(item["CreateTime"]),
                isObtained: level >= 3
            )
        }
    }

    private static func fetchModules(encUin: String, tabID: Int) async -> [MedalModule] {
        guard !encUin.isEmpty else { return [] }
        let payload: [String: Any] = [
            "comm": [String: Any](),
            "req_0": [
                "module": "music.medalHall.MedalHallHomepageSrv",
                "method": "GetHomepageTabDetail",
                "param": [
                    "EncUin": encUin,
                    "TabID": tabID,
                    "IsQueryTabDetail": true,
                    "SupportCardStyle": true
                ]
            ]
        ]

        guard let response = await post(
            webcgikey: "GetHomepageTabDetail",
            payload: payload
        ),
        let requestZero = response["req_0"] as? [String: Any],
        NodePortSupport.int(requestZero["code"]) == 0,
        let data = requestZero["data"] as? [String: Any] else {
            return []
        }

        let tabInfo = NodePortSupport.dictionary(data["TabInfo"])
        return parseModules(tabInfo["ModuleList"])
    }

    private static func post(
        webcgikey: String,
        payload: [String: Any]
    ) async -> [String: Any]? {
        guard let bodyData = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        ),
        let body = String(data: bodyData, encoding: .utf8) else {
            return nil
        }

        let signature = QQMusicAPI.sign(body)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        guard let url = URL(
            string: "\(apiURL)?_webcgikey=\(webcgikey)&_=\(timestamp)&sign=\(signature)"
        ) else {
            return nil
        }

        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return nil
        }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

enum MedalHallError: LocalizedError {
    case invalidURL
    case invalidResponse
    case noTabs

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "请输入有效的勋章馆链接。"
        case .invalidResponse: return "未能读取勋章馆页面。"
        case .noTabs: return "页面中没有勋章分类。"
        }
    }
}
