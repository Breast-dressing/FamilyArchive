//
//  PlayerSettingsStore.swift
//  FamilyArchive
//
//  Lyricify Mobile 设置页里的播放器选项，落在 UserDefaults。
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class PlayerSettingsStore {
    private enum Key {
        static let source = "player.lyricsSource"
        static let translation = "player.showTranslation"
        static let bold = "player.boldText"
        static let fontScale = "player.fontScale"
        static let blurScale = "player.blurScale"
        static let pull = "player.pullEffect"
        static let latency = "player.lyricsLatency"
    }

    private let defaults: UserDefaults

    var source: LyricsSource {
        didSet { defaults.set(source.rawValue, forKey: Key.source) }
    }

    /// 中文翻译
    var showTranslation: Bool {
        didSet { defaults.set(showTranslation, forKey: Key.translation) }
    }

    /// 粗体文本
    var boldText: Bool {
        didSet { defaults.set(boldText, forKey: Key.bold) }
    }

    /// 字号缩放
    var fontScale: Double {
        didSet { defaults.set(fontScale, forKey: Key.fontScale) }
    }

    /// 模糊半径缩放
    var blurScale: Double {
        didSet { defaults.set(blurScale, forKey: Key.blurScale) }
    }

    /// 拖动效果
    var pullEffect: Bool {
        didSet { defaults.set(pullEffect, forKey: Key.pull) }
    }

    /// 歌词延迟（秒），正数表示歌词更晚出现。
    var latency: Double {
        didSet { defaults.set(latency, forKey: Key.latency) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        source = LyricsSource(rawValue: defaults.string(forKey: Key.source) ?? "")
            ?? .qqMusic
        showTranslation = defaults.object(forKey: Key.translation) as? Bool ?? true
        boldText = defaults.object(forKey: Key.bold) as? Bool ?? true
        fontScale = defaults.object(forKey: Key.fontScale) as? Double ?? 1
        blurScale = defaults.object(forKey: Key.blurScale) as? Double ?? 1
        pullEffect = defaults.object(forKey: Key.pull) as? Bool ?? true
        latency = defaults.object(forKey: Key.latency) as? Double ?? 0
    }

    /// 当前行字号。
    func lyricFont(current: Bool) -> Font {
        let size = (current ? 24.0 : 19.0) * fontScale
        return boldText || current
            ? .system(size: size, weight: current ? .bold : .semibold)
            : .system(size: size, weight: .regular)
    }

    var translationFont: Font {
        .system(size: 14 * fontScale, weight: .regular)
    }

    var backgroundBlurRadius: Double {
        46 * max(blurScale, 0)
    }
}
