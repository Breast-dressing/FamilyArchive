import Foundation
import SwiftData

/// 影视分类，对应顶部的 剧集 / 电影 / 综艺 / 花絮。
enum VideoCategory: String, CaseIterable, Identifiable, Hashable {
    case episode = "剧集"
    case movie = "电影"
    case variety = "综艺"
    case behind = "花絮"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// 影视状态。顶部大图右侧显示 待播 / 待拍 的数量。
enum VideoStatus: String, CaseIterable, Identifiable, Hashable {
    case pending = "待播"
    case shooting = "待拍"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// The 影视 page's top tabs: 全部 first, then every category.
enum VideoFilter {
    static let allTag = "全部"

    static var tags: [String] {
        [allTag] + VideoCategory.allCases.map(\.rawValue)
    }

    static func matches(_ show: VideoShow, tag: String) -> Bool {
        tag == allTag || show.category == tag
    }

    static func shows(_ shows: [VideoShow], tag: String) -> [VideoShow] {
        shows.filter { matches($0, tag: tag) }
    }

    static func count(of shows: [VideoShow], status: VideoStatus) -> Int {
        shows.filter { $0.status == status.rawValue }.count
    }
}

/// 顶部横向大图取过滤后最新的一条。
enum VideoLayout {
    static func featured(in shows: [VideoShow]) -> VideoShow? {
        shows.first
    }
}

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
    /// 剧集 / 电影 / 综艺 / 花絮
    var category: String = VideoCategory.episode.rawValue
    /// 待播 / 待拍，由 ＋ 新建影视时手动选择。
    var status: String = VideoStatus.pending.rawValue

    init(
        id: UUID = UUID(),
        platform: String,
        title: String,
        synopsis: String,
        cast: String,
        coverData: Data? = nil,
        episodeTitles: [String] = [],
        episodeFileNames: [String] = [],
        createdAt: Date = .now,
        category: String = VideoCategory.episode.rawValue,
        status: String = VideoStatus.pending.rawValue
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
        self.category = category
        self.status = status
    }
}
