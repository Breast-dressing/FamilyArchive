//
//  MusicRootView.swift
//  FamilyArchive
//
//  The Music page. Its toolbar title area holds a native segmented control with
//  "Music" and "Archive". "Account" is always the rightmost toolbar button;
//  "More" only exists while "Archive" is selected and sits left of Account.
//

import SwiftUI

struct MusicRootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.musicPath) {
            Group {
                if router.musicSection == .music {
                    MusicHomeView()
                } else {
                    ArchiveView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Music section", selection: $router.musicSection) {
                        Text("Music").tag(MusicSection.music)
                        Text("Archive").tag(MusicSection.archive)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if router.musicSection == .archive {
                        // Visibility and position are required; no action is
                        // specified for this button in the specification.
                        Button("More") {}
                    }

                    // Always visible and rightmost.
                    Button("Account") {}
                }
            }
            .navigationDestination(for: String.self) { familyURL in
                FamilyDetailView(familyURL: familyURL)
            }
        }
    }
}
