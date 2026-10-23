import Foundation
import SwiftData

@Model
final class FeedPost {
    @Attribute(.unique) var id: UUID
    var platform: String
    var caption: String
    var mediaData: [Data]
    var mediaIsVideo: [Bool]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        platform: String,
        caption: String,
        mediaData: [Data] = [],
        mediaIsVideo: [Bool] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.platform = platform
        self.caption = caption
        self.mediaData = mediaData
        self.mediaIsVideo = mediaIsVideo
        self.createdAt = createdAt
    }
}
