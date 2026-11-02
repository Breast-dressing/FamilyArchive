//
//  AppRouter.swift
//  FamilyArchive
//
//  Shared navigation state. The main tab bar and the Music toolbar both read
//  and write this object, so the floating toolbar can decide what to present
//  based on the *current* page/tab.
//

import Foundation
import Observation

/// The four main tab bar items, in display order. 更多 is rendered detached by
/// the system (`role: .prominent`).
enum RootTab: String, Hashable, CaseIterable {
    case feed
    case video
    case music
    case more

    var title: String {
        switch self {
        case .feed:
            return "动态"
        case .video:
            return "影视"
        case .music:
            return "音乐"
        case .more:
            return "个人"
        }
    }

    var systemImage: String {
        switch self {
        case .feed:
            return "square.stack"
        case .video:
            return "play.rectangle"
        case .music:
            return "music.note"
        case .more:
            return "person.crop.circle"
        }
    }
}

/// 个人页的导航路径（家族 / 成员 / 乐迷 / 勋章 / 卡牌）。
enum ProfileRoute: Hashable {
    case family(String)
    case member(familyURL: String, memberID: String)
    case fans
    case medals
    case cards
}

/// What the detached "＋" tab should present for the current page.
enum PlusRoute: Identifiable, Equatable {
    case archiveActions
    case unavailable(pageName: String)

    var id: String {
        switch self {
        case .archiveActions:
            return "archiveActions"
        case .unavailable(let pageName):
            return "unavailable-\(pageName)"
        }
    }
}

@Observable
final class AppRouter {
    var selectedTab: RootTab = .feed

    /// 个人页的导航路径。
    var profilePath: [ProfileRoute] = []

    /// True while a post detail is pushed on the Feed tab.
    var isFeedDetailActive = false
}
