//
//  Lyrics.swift
//  FamilyArchive
//
//  Lyricify Mobile 的歌词能力用 Swift 重写：逐行 / 逐字、翻译、卡拉 OK 填充进度。
//

import Foundation

struct LyricWord: Equatable {
    let start: Double
    let text: String
}

struct LyricLine: Identifiable, Equatable {
    let id: Int
    /// 该行开始时间（秒）。
    let time: Double
    let text: String
    var translation: String?
    var words: [LyricWord] = []

    init(
        id: Int,
        time: Double,
        text: String,
        translation: String? = nil,
        words: [LyricWord] = []
    ) {
        self.id = id
        self.time = time
        self.text = text
        self.translation = translation
        self.words = words
    }
}

/// 一份歌词：逐行 + 可选翻译。
struct LyricsDocument: Equatable {
    var lines: [LyricLine]
    var isInstrumental = false

    static let empty = LyricsDocument(lines: [])

    var isEmpty: Bool { lines.isEmpty }
}

enum LyricsAnimation {
    /// 当前行：最后一条 `time <= current`；早于第一行时为 nil。
    static func currentIndex(in lines: [LyricLine], at time: Double) -> Int? {
        guard let first = lines.first, time >= first.time else { return nil }
        var result: Int?
        for (index, line) in lines.enumerated() where line.time <= time {
            result = index
        }
        return result
    }
}

enum PlaybackTime {
    /// 播放器与播放条共用的时间写法。
    static func text(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
