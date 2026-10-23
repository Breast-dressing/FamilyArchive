import Foundation
import SwiftData

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
    var platform: String
    @Attribute(.externalStorage) var avatarData: Data?
    @Attribute(.externalStorage) var platformLogoData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        username: String,
        platform: String,
        avatarData: Data? = nil,
        platformLogoData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.username = username
        self.platform = platform
        self.avatarData = avatarData
        self.platformLogoData = platformLogoData
        self.createdAt = createdAt
    }
}
