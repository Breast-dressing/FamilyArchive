//
//  FeedPresentation.swift
//  FamilyArchive
//
//  Pure rules behind the 动态 cards: how many columns the media grid uses, which
//  glyph stands for a 来源, and how the 时间 is written. Kept out of the view so
//  the logic tests can pin them without SwiftUI.
//

import Foundation

enum MediaGridRules {
    /// 三种模板：1 张 = 1 图网格（整行），4 张 = 4 图网格（2×2），
    /// 9 张及以上 = 9 图网格（3×3）；2、3、5…8 张复用最接近的模板。
    static func columns(for count: Int) -> Int {
        switch count {
        case ...1: return 1
        case 4: return 2
        default: return 3
        }
    }

    /// 一屏最多显示的格子数：1 图 / 4 图 / 9 图。
    static func capacity(for count: Int) -> Int {
        switch columns(for: count) {
        case 1: return 1
        case 2: return 4
        default: return 9
        }
    }
}

enum FeedSourceIcon {
    /// 来源对应的 SF Symbol；未知来源统一用地球。
    static func symbol(for platform: String) -> String {
        switch platform {
        case SocialPlatform.weibo.rawValue: return "bubble.left"
        case SocialPlatform.xiaohongshu.rawValue: return "book"
        case SocialPlatform.douyin.rawValue: return "music.note"
        case SocialPlatform.bilibili.rawValue: return "play.tv"
        case SocialPlatform.wechatChannels.rawValue: return "video"
        default: return "globe"
        }
    }
}

enum FeedFooter {
    /// 同年只写「M月d日」，跨年补上年份。
    static func timeText(
        for date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        let sameYear = calendar.component(.year, from: date)
            == calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = sameYear ? "M月d日" : "yyyy年M月d日"
        return formatter.string(from: date)
    }
}
