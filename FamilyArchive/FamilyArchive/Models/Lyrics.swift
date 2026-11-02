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
    /// 当前行已唱到多少（0…1）。逐字时按字宽累计，逐行时按本行到下一行的时间。
    static func fillProgress(
        for line: LyricLine,
        at time: Double,
        nextStart: Double?
    ) -> Double {
        guard time >= line.time else { return 0 }

        if !line.words.isEmpty {
            let total = line.words.reduce(0) { $0 + max($1.text.count, 1) }
            guard total > 0 else { return 1 }
            var filled = 0.0
            for (index, word) in line.words.enumerated() {
                // 最后一个词按自身长度收口，不会被到下一行的长间隔拉长。
                let natural = word.start + max(Double(max(word.text.count, 1)) * 0.3, 0.5)
                let wordEnd = index + 1 < line.words.count
                    ? line.words[index + 1].start
                    : min(nextStart ?? natural, natural)
                let weight = Double(max(word.text.count, 1))
                if time >= wordEnd {
                    filled += weight
                } else if time > word.start {
                    filled += weight * ((time - word.start) / max(wordEnd - word.start, 0.01))
                }
            }
            return min(max(filled / Double(total), 0), 1)
        }

        let end = nextStart ?? line.time + 4
        guard end > line.time else { return 1 }
        return min(max((time - line.time) / (end - line.time), 0), 1)
    }

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

enum LRCParser {
    /// 解析 LRC：兼容 `[mm:ss.xx]行`、逐字 `<mm:ss.xx>` 与同时间戳的翻译行。
    static func parse(_ source: String) -> [LyricLine] {
        var entries: [(time: Double, text: String, words: [LyricWord])] = []

        for rawLine in source.split(whereSeparator: \.isNewline) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("["), let close = trimmed.firstIndex(of: "]") else { continue }

            let stamp = trimmed[trimmed.index(after: trimmed.startIndex)..<close]
            guard let time = seconds(from: stamp) else { continue }

            var body = String(trimmed[trimmed.index(after: close)...])
                .trimmingCharacters(in: .whitespaces)
            var words: [LyricWord] = []

            if let firstWord = body.firstIndex(of: "<") {
                let wordsPart = String(body[firstWord...])
                body = String(body[..<firstWord]).trimmingCharacters(in: .whitespaces)
                words = parseWords(wordsPart, lineStart: time)
            }

            // 逐字行没有「标签前的正文」，行文本由词拼回来。
            let lineText = words.isEmpty
                ? plainText(from: body)
                : words.map(\.text).joined()
            entries.append((time, lineText, words))
        }

        entries.sort { $0.time == $1.time ? false : $0.time < $1.time }

        var merged: [(time: Double, text: String, words: [LyricWord], translation: String?)] = []
        for entry in entries {
            if let last = merged.last, abs(last.time - entry.time) < 0.01 {
                // 同一时间戳的第二行视为翻译。
                if merged[merged.count - 1].translation == nil, !entry.text.isEmpty {
                    merged[merged.count - 1].translation = entry.text
                }
                continue
            }
            merged.append((entry.time, entry.text, entry.words, nil))
        }

        return merged.enumerated().map { index, entry in
            LyricLine(
                id: index,
                time: entry.time,
                text: entry.text,
                translation: entry.translation,
                words: entry.words
            )
        }
    }

    static func seconds(from stamp: Substring) -> Double? {
        let parts = stamp.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let minutes = Double(parts[0]) else { return nil }
        let rest = String(parts[1]).replacingOccurrences(of: ",", with: ".")
        guard let seconds = Double(rest) else { return nil }
        return minutes * 60 + seconds
    }

    /// `<mm:ss.xx>字` 形式的逐字时间点。
    private static func parseWords(_ source: String, lineStart: Double) -> [LyricWord] {
        var words: [LyricWord] = []
        var rest = Substring(source)
        var pending: Double?

        while let open = rest.firstIndex(of: "<"),
              let close = rest[open...].firstIndex(of: ">") {
            let stamp = rest[rest.index(after: open)..<close]
            let text = String(rest[..<open])
            if let pending, !text.isEmpty {
                words.append(LyricWord(start: pending, text: text))
            }
            pending = seconds(from: stamp) ?? lineStart
            rest = rest[rest.index(after: close)...]
        }

        let tail = String(rest)
        if let pending, !tail.isEmpty {
            words.append(LyricWord(start: pending, text: tail))
        }
        return words
    }

    private static func plainText(from body: String) -> String {
        body.replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
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
