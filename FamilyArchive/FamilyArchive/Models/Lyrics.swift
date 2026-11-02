//
//  Lyrics.swift
//  FamilyArchive
//
//  LRC 解析与当前行定位。播放器只吃这里的纯数据，动画在视图层。
//

import Foundation

struct LyricLine: Identifiable, Equatable {
    let id: Int
    /// 该行开始时间（秒）。
    let time: Double
    let text: String
}

enum LRCParser {
    /// 解析 `[mm:ss.xx]文本`，按时间排序并重新编号。
    static func parse(_ source: String) -> [LyricLine] {
        var raw: [(time: Double, text: String)] = []

        for line in source.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("["), let close = trimmed.firstIndex(of: "]") else { continue }

            let stamp = trimmed[trimmed.index(after: trimmed.startIndex)..<close]
            let text = String(trimmed[trimmed.index(after: close)...])
                .trimmingCharacters(in: .whitespaces)
            guard let time = seconds(from: stamp) else { continue }
            raw.append((time, text))
        }

        return raw
            .enumerated()
            .sorted { lhs, rhs in
                lhs.element.time == rhs.element.time
                    ? lhs.offset < rhs.offset
                    : lhs.element.time < rhs.element.time
            }
            .enumerated()
            .map { index, entry in
                LyricLine(id: index, time: entry.element.time, text: entry.element.text)
            }
    }

    /// 当前时间对应的行：最后一条 `time <= current`；早于第一行时为 nil。
    static func currentIndex(in lines: [LyricLine], at time: Double) -> Int? {
        guard !lines.isEmpty, let first = lines.first, time >= first.time else { return nil }
        var result: Int?
        for (index, line) in lines.enumerated() where line.time <= time {
            result = index
        }
        return result
    }

    private static func seconds(from stamp: Substring) -> Double? {
        let parts = stamp.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let minutes = Double(parts[0]) else { return nil }
        let rest = String(parts[1]).replacingOccurrences(of: ",", with: ".")
        guard let seconds = Double(rest) else { return nil }
        return minutes * 60 + seconds
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
