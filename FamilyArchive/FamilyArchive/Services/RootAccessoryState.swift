//
//  RootAccessoryState.swift
//  FamilyArchive
//
//  Parent-owned state for the TabView bottom accessory. RootView owns the only
//  instance, so switching tabs or pushing views can never drop the accessory's
//  presentation state. Accessory views are pure renderers over this object.
//

import Foundation
import Observation

/// Which accessory the Music tab shows. Resolved by RootView from the
/// Music navigation path, never by the accessory itself.
enum MusicAccessoryForm: Equatable {
    case search
    case family
}

/// Transition source identifiers shared by `matchedTransitionSource` and the
/// zoom transition of the presented sheet.
enum AccessoryTransition {
    static let dateFilter = "accessory.dateFilter"
    static let pendingFiles = "accessory.pendingFiles"
    static let plus = "accessory.plus"
}

/// Transition source identifiers for the 账号 sheet.
///
/// The sheet is presented from a NavigationBar button that lives *inside* each
/// tab, not from the shared bottom accessory, so every scope keeps its own id:
/// one id shared by three tabs would let the zoom transition anchor on a source
/// that is not the one on screen. `AccountScope` is the only input, so a scope
/// can never be added without a source id.
enum AccountsTransitionSource {
    static func sourceID(for scope: AccountScope) -> String {
        "accounts.\(scope.rawValue)"
    }

    /// Every source id the app registers, for collision checks.
    static var allIDs: [String] {
        AccountScope.allCases.map(sourceID(for:))
    }
}

@Observable
final class RootAccessoryState {
    var musicForm: MusicAccessoryForm = .search

    var familyURL: String?
    var memberName: String?
    var dateLabel = ""
    var pendingCount = 0

    var feedSearchText = ""
    var isFeedSearchActive = false
    var videoSearchText = ""
    var musicSearchText = ""

    /// Family page entry. Resets the member so returning from a member page
    /// restores the "日期筛选" form.
    func enterFamily(familyURL: String, dateLabel: String, pendingCount: Int) {
        self.familyURL = familyURL
        self.memberName = nil
        self.dateLabel = dateLabel
        self.pendingCount = pendingCount
        self.musicForm = .family
    }

    /// Date range or pending list changed while the family page is visible.
    func updateFamily(dateLabel: String, pendingCount: Int) {
        self.dateLabel = dateLabel
        self.pendingCount = pendingCount
        self.musicForm = .family
    }

    /// Member page entry. Keeps the family form, only the member changes.
    func enterMember(name: String, familyURL: String, dateLabel: String, pendingCount: Int) {
        self.familyURL = familyURL
        self.memberName = name
        self.dateLabel = dateLabel
        self.pendingCount = pendingCount
        self.musicForm = .family
    }

    /// Back to the Music root (or leaving the Music tab with an empty path).
    func leaveFamily() {
        musicForm = .search
        familyURL = nil
        memberName = nil
        pendingCount = 0
    }
}
