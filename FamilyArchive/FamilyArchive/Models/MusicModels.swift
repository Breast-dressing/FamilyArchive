import Foundation
import SwiftData

/// 音乐分类，对应顶部的 独唱 / 清唱 / 合唱。
enum SongCategory: String, CaseIterable, Identifiable, Hashable {
    case solo = "独唱"
    case aCapella = "清唱"
    case chorus = "合唱"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// The 音乐 page's top tabs: 全部 first, then every category.
enum SongFilter {
    static let allTag = "全部"

    static var tags: [String] {
        [allTag] + SongCategory.allCases.map(\.rawValue)
    }

    static func matches(_ song: Song, tag: String) -> Bool {
        tag == allTag || song.category == tag
    }

    static func songs(_ songs: [Song], tag: String) -> [Song] {
        songs.filter { matches($0, tag: tag) }
    }
}

/// 自建歌单，音乐页上方三列展示。
@Model
final class Playlist {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.externalStorage) var coverData: Data?
    var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        coverData: Data? = nil,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.coverData = coverData
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

/// 歌曲合集，音乐页下方横向长卡片展示。
@Model
final class SongCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.externalStorage) var coverData: Data?
    var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        coverData: Data? = nil,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.coverData = coverData
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

/// 一首歌。音频文件通过 ＋ 从本地导入，`fileName` 是 `AudioFileStore` 里的相对名。
@Model
final class Song {
    @Attribute(.unique) var id: UUID
    var title: String
    var artist: String
    /// 独唱 / 清唱 / 合唱
    var category: String = SongCategory.solo.rawValue
    /// `AudioFileStore` 里的相对文件名。
    var fileName: String = ""
    /// 秒；由播放器读取音频后回填，未知时为 0。
    var duration: Double = 0
    /// 所属歌单（可选）。
    var playlistID: UUID?
    /// 所属合集（可选）。
    var collectionID: UUID?
    var sortOrder: Int = 0
    var createdAt: Date
    /// LRC 文本；播放器按它定位当前行。
    var lyricsText: String = ""

    init(
        id: UUID = UUID(),
        title: String,
        artist: String = "",
        category: String = SongCategory.solo.rawValue,
        fileName: String = "",
        duration: Double = 0,
        playlistID: UUID? = nil,
        collectionID: UUID? = nil,
        sortOrder: Int = 0,
        createdAt: Date = .now,
        lyricsText: String = ""
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.category = category
        self.fileName = fileName
        self.duration = duration
        self.playlistID = playlistID
        self.collectionID = collectionID
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.lyricsText = lyricsText
    }
}
