//
//  AppRouter.swift
//  FamilyArchive
//
//  Shared navigation state. The main tab bar and the Music toolbar both read
//  and write this object, which is what lets the detached "＋" tab decide what
//  to present based on the *current* page/tab.
//

import Foundation
import Observation

/// The five main tab bar items. `.plus` is the detached item and is deliberately
/// never written into `selectedTab`.
enum RootTab: Hashable {
    case feed
    case video
    case music
    case more
    case plus
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

    var familyURL: String {
        switch self {
        case .family(let familyURL):
            return familyURL
        case .member(let familyURL, _):
            return familyURL
        }
    }
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
    /// user is on a family or member page, which changes the "＋" behaviour.
    var musicPath: [MusicRoute] = []

    var plusRoute: PlusRoute?
}
