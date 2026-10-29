import Foundation
import SwiftData

enum AccountScope: String, CaseIterable, Identifiable {
    case feed = "feed"
    case video = "video"
    case music = "music"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .feed: return "动态"
        case .video: return "影视"
        case .music: return "音乐"
        }
    }
}

enum SocialPlatform: String, CaseIterable, Identifiable, Hashable {
    case weibo = "微博"
    case xiaohongshu = "小红书"
    case douyin = "抖音"
    case bilibili = "哔哩哔哩"
    case wechatChannels = "视频号"

    var id: String { rawValue }
    var title: String { rawValue }

    /// One tab per platform, in the canonical order, regardless of how many
    /// accounts exist for that platform.
    static func uniquePlatforms(from accounts: [Account]) -> [String] {
        let present = Set(accounts.map(\.platform))
        var result = allCases.map(\.rawValue).filter { present.contains($0) }
        for platform in present where !result.contains(platform) {
            result.append(platform)
        }
        return result
    }
}

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var username: String
    /// QQ 音乐账号 ID，所有自动查询都以它为 enc_uin。
    var encUin: String = ""
    var platform: String
    /// 动态 / 影视 / 音乐各自独立，不共享账号数据。
    var scope: String = AccountScope.feed.rawValue
    @Attribute(.externalStorage) var avatarData: Data?
    @Attribute(.externalStorage) var platformLogoData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        username: String,
        encUin: String = "",
        platform: String,
        scope: String = AccountScope.feed.rawValue,
        avatarData: Data? = nil,
        platformLogoData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.username = username
        self.encUin = encUin
        self.platform = platform
        self.scope = scope
        self.avatarData = avatarData
        self.platformLogoData = platformLogoData
        self.createdAt = createdAt
    }
}
