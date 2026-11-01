import Foundation
import SwiftData

/// Who a 动态 belongs to. The 动态 filter tabs are 全部 + these three groups.
enum FeedOwnerGroup: String, CaseIterable, Identifiable, Hashable {
    case baby = "宝宝"
    case studio = "小室"
    case client = "甲方"

    var id: String { rawValue }
    var title: String { rawValue }
}

/// The 动态 page's top tabs: 全部 first, then every owner group.
enum FeedFilter {
    static let allTag = "全部"

    static var tags: [String] {
        [allTag] + FeedOwnerGroup.allCases.map(\.rawValue)
    }

    /// `全部` keeps everything; any other tag keeps only that owner group.
    static func matches(_ post: FeedPost, tag: String) -> Bool {
        tag == allTag || post.ownerGroup == tag
    }

    static func posts(_ posts: [FeedPost], tag: String) -> [FeedPost] {
        posts.filter { matches($0, tag: tag) }
    }
}

@Model
final class FeedPost {
    @Attribute(.unique) var id: UUID
    var platform: String
    var caption: String
    var mediaData: [Data]
    var mediaIsVideo: [Bool]
    var createdAt: Date
    /// 宝宝 / 小室 / 甲方
    var ownerGroup: String = FeedOwnerGroup.baby.rawValue
    /// 发布者，显示在标题行的右侧。
    var author: String = ""
    /// 左下角标题。为空时回退到 `caption`。
    var title: String = ""

    init(
        id: UUID = UUID(),
        platform: String,
        caption: String,
        mediaData: [Data] = [],
        mediaIsVideo: [Bool] = [],
        createdAt: Date = .now,
        ownerGroup: String = FeedOwnerGroup.baby.rawValue,
        author: String = "",
        title: String = ""
    ) {
        self.id = id
        self.platform = platform
        self.caption = caption
        self.mediaData = mediaData
        self.mediaIsVideo = mediaIsVideo
        self.createdAt = createdAt
        self.ownerGroup = ownerGroup
        self.author = author
        self.title = title
    }

    /// 左下角显示的文字。
    var displayTitle: String {
        title.isEmpty ? caption : title
    }
}
