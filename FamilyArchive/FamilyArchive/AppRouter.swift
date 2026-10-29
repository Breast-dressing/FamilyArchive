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
            return "更多"
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
            return "ellipsis"
        }
    }
}

/// The two tabs of the native segmented control in the Music toolbar.
enum MusicSection: String, Hashable, CaseIterable {
    case music = "Music"
    case archive = "Archive"
}

/// Value-based Music navigation stack. Member pages are real path values so
/// RootView can keep the bottom accessory in sync for every push and pop.
enum MusicRoute: Hashable {
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
    var musicSection: MusicSection = .music

    /// Routes pushed on the Music tab's navigation stack. When non-empty the
    /// user is on a family or member page, which hides the custom bottom bar.
    var musicPath: [MusicRoute] = []

    /// True while a post detail is pushed on the Feed tab.
    var isFeedDetailActive = false
}
