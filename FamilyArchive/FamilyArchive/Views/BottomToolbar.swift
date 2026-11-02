//
//  BottomToolbar.swift
//  FamilyArchive
//
//  Metrics shared by the floating chrome. The old search / date / plus bar was
//  replaced by the playback bar in step 7; only the spacing constants remain.
//

import SwiftUI

enum BottomToolbarLayout {
    /// Horizontal inset shared by the floating playback bar and the floating tab
    /// bar so both edges line up on the same vertical grid.
    static let horizontalInset: CGFloat = 21

    /// The controls use the same 44pt hit area as the circular buttons in the
    /// page's NavigationBar, so the top and bottom chrome read as one system.
    static let controlSize: CGFloat = 44
}
