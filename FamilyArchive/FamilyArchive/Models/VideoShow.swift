import Foundation
import SwiftData

@Model
final class VideoShow {
    @Attribute(.unique) var id: UUID
    var platform: String
    var title: String
    var synopsis: String
    var cast: String
    @Attribute(.externalStorage) var coverData: Data?
    var episodeTitles: [String]
    var episodeFileNames: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        platform: String,
        title: String,
        synopsis: String,
        cast: String,
        coverData: Data? = nil,
        episodeTitles: [String] = [],
        episodeFileNames: [String] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.platform = platform
        self.title = title
        self.synopsis = synopsis
        self.cast = cast
        self.coverData = coverData
        self.episodeTitles = episodeTitles
        self.episodeFileNames = episodeFileNames
        self.createdAt = createdAt
    }
}
