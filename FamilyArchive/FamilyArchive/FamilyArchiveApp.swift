import SwiftData
import SwiftUI

@main
struct FamilyArchiveApp: App {
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: Family.self,
                FamilyMember.self,
                HonorRecord.self,
                Account.self,
                FeedPost.self,
                VideoShow.self,
                FamilyAvatarHistory.self,
                BadgeSkinRecord.self,
                BadgeQueryState.self,
                MedalTabRecord.self,
                Playlist.self,
                SongCollection.self,
                Song.self,
                UserProfile.self
            )
        } catch {
            fatalError("Failed to create the SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
