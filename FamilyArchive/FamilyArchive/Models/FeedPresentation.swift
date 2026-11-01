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
    /// 1 张占满一行，4 张走 2×2，其余（2、3、5…9）走三列九宫格。
    static func columns(for count: Int) -> Int {
        switch count {
        case ...1: return 1
        case 4: return 2
        default: return 3
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
