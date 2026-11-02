//
//  LyricsService.swift
//  FamilyArchive
//
//  Lyricify Mobile 的歌词源（QQ 音乐 / 网易云 / 酷狗）在这里用公开接口重写。
//  解析与 URL 组装是纯函数，网络请求只负责把 JSON 交给它们。
//

import Foundation

enum LyricsSource: String, CaseIterable, Identifiable, Hashable {
    case qqMusic = "QQ 音乐"
    case netease = "网易云音乐"
    case kugou = "酷狗音乐"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// 歌词服务：搜索 + 取词，全部走公开接口。
enum LyricsService {
    /// 纯函数：组装搜索 URL。
    static func searchURL(source: LyricsSource, keyword: String) -> URL? {
        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        switch source {
        case .qqMusic:
            return URL(string: "https://c.y.qq.com/soso/fcgi-bin/client_search_cp?format=json&n=1&w=\(encoded)")
        case .netease:
            return URL(string: "https://music.163.com/api/search/get?s=\(encoded)&type=1&limit=1")
        case .kugou:
            return URL(string: "https://krcs.kugou.com/search?ver=1&man=yes&client=mobi&keyword=\(encoded)")
        }
    }

    /// 纯函数：从搜索响应里取第一首歌的标识。
    static func songID(source: LyricsSource, from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        switch source {
        case .qqMusic:
            let list = ((json["data"] as? [String: Any])?["song"] as? [String: Any])?["list"] as? [[String: Any]]
            return list?.first?["songmid"] as? String
        case .netease:
            let songs = (json["result"] as? [String: Any])?["songs"] as? [[String: Any]]
            return songs?.first?["id"].map { "\($0)" }
        case .kugou:
            let candidates = json["candidates"] as? [[String: Any]]
            guard let first = candidates?.first,
                  let id = first["id"], let key = first["accesskey"] else { return nil }
            return "\(id)|\(key)"
        }
    }

    /// 纯函数：取词 URL。
    static func lyricURL(source: LyricsSource, songID: String) -> URL? {
        switch source {
        case .qqMusic:
            return URL(string: "https://c.y.qq.com/lyric/fcgi-bin/fcg_query_lyric_new.fcg?format=json&nobase64=1&songmid=\(songID)")
        case .netease:
            return URL(string: "https://music.163.com/api/song/lyric?id=\(songID)&lv=-1&kv=-1&tv=-1")
        case .kugou:
            let parts = songID.split(separator: "|")
            guard parts.count == 2 else { return nil }
            return URL(string: "https://krcs.kugou.com/download?ver=1&client=mobi&fmt=lrc&charset=utf8&id=\(parts[0])&accesskey=\(parts[1])")
        }
    }

    /// 纯函数：把取词响应解析成（歌词, 翻译）。
    static func decode(source: LyricsSource, from data: Data) -> (lyrics: String, translation: String?)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        switch source {
        case .qqMusic:
            guard let lyric = json["lyric"] as? String else { return nil }
            return (lyric, json["trans"] as? String)
        case .netease:
            let lyric = (json["lrc"] as? [String: Any])?["lyric"] as? String
            guard let lyric else { return nil }
            return (lyric, (json["tlyric"] as? [String: Any])?["lyric"] as? String)
        case .kugou:
            guard let base64 = json["content"] as? String,
                  let decoded = Data(base64Encoded: base64),
                  let text = String(data: decoded, encoding: .utf8) else { return nil }
            return (text, nil)
        }
    }

    /// 离线也能用：本地 LRC 优先，其次再联网。
    static func load(
        title: String,
        artist: String,
        localLyrics: String,
        source: LyricsSource
    ) async -> LyricsDocument {
        if !localLyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return document(from: localLyrics, translation: nil)
        }
        guard !title.isEmpty,
              let document = await fetch(title: title, artist: artist, source: source),
              !document.isEmpty else {
            return .empty
        }
        return document
    }

    static func fetch(title: String, artist: String, source: LyricsSource) async -> LyricsDocument? {
        let keyword = artist.isEmpty ? title : "\(title) \(artist)"
        guard let searchURL = searchURL(source: source, keyword: keyword),
              let searchData = await get(searchURL),
              let songID = songID(source: source, from: searchData),
              let lyricURL = lyricURL(source: source, songID: songID),
              let lyricData = await get(lyricURL),
              let decoded = decode(source: source, from: lyricData) else {
            return nil
        }
        return document(from: decoded.lyrics, translation: decoded.translation)
    }

    static func document(from lyrics: String, translation: String?) -> LyricsDocument {
        let text = lyrics.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return LyricsDocument(lines: [], isInstrumental: true)
        }
        var lines = LRCParser.parse(text)
        if let translation {
            let translated = LRCParser.parse(translation)
            for line in translated {
                if let index = lines.firstIndex(where: { abs($0.time - line.time) < 0.01 }) {
                    lines[index].translation = line.text
                }
            }
        }
        return LyricsDocument(lines: lines)
    }

    private static func get(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("https://music.163.com", forHTTPHeaderField: "Referer")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return data
    }
}
