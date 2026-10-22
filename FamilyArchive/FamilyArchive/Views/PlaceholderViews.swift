//
//  PlaceholderViews.swift
//  FamilyArchive
//
//  Feed / Video / More / Music content is freely designed by the
//  specification. These pages are intentionally minimal and do not affect the
//  required interactions.
//

import SwiftUI

struct FeedView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Feed",
                systemImage: "square.stack",
                description: Text("The Feed page is not part of this build.")
            )
            .navigationTitle("Feed")
        }
    }
}

struct VideoView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Video",
                systemImage: "play.rectangle",
                description: Text("The Video page is not part of this build.")
            )
            .navigationTitle("Video")
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "More",
                systemImage: "ellipsis.circle",
                description: Text("The More page is not part of this build.")
            )
            .navigationTitle("More")
        }
    }
}

struct MusicHomeView: View {
    var body: some View {
        ContentUnavailableView(
            "Music",
            systemImage: "music.note",
            description: Text("Switch to Archive to manage families and import HAR files.")
        )
    }
}
