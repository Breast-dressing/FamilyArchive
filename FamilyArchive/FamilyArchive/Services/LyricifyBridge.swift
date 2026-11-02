//
//  LyricifyBridge.swift
//  FamilyArchive
//
//  上游 Lyricify Lyrics Helper（Swift 包，Apache-2.0，固定 commit）与播放器模型之间的桥。
//  解析全部交给上游的 ParseHelper，本文件只做单位换算（毫秒 → 秒）与视图字段映射。
//

import Foundation
import LyricifyLyricsHelper

enum LyricifyBridge {
    /// 原始歌词文本 → 播放器模型。
    static func document(_ text: String) -> LyricsDocument {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let parsed = try? ParseHelper.parseLyrics(text),
              let lines = parsed.lines,
              !lines.isEmpty else {
            return .empty
        }
        return document(from: lines)
    }

    static func document(from lines: [Line]) -> LyricsDocument {
        let mapped: [LyricLine] = lines.enumerated().map { index, line in
            let words = line.syllables.map { syllable in
                LyricWord(
                    start: Double(syllable.startTime ?? 0) / 1000,
                    text: syllable.text
                )
            }
            return LyricLine(
                id: index,
                time: Double(line.startTime ?? 0) / 1000,
                text: line.text,
                translation: line.translations["zh"] ?? line.translations.values.first,
                words: words
            )
        }
        return LyricsDocument(lines: mapped)
    }

    /// 翻译歌词文本按时间并入。
    static func merging(
        translation: String,
        into document: LyricsDocument
    ) -> LyricsDocument {
        let translated = Self.document(translation)
        guard !translated.isEmpty else { return document }

        var lines = document.lines
        for line in translated.lines {
            if let index = lines.firstIndex(where: { abs($0.time - line.time) < 0.05 }) {
                lines[index].translation = line.text
            }
        }
        return LyricsDocument(lines: lines)
    }
}
