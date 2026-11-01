import Foundation
import SwiftData

/// 个人页顶部长方形卡片的信息来源。整个 App 只有一份。
@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.externalStorage) var avatarData: Data?
    var signature: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        avatarData: Data? = nil,
        signature: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.avatarData = avatarData
        self.signature = signature
        self.updatedAt = updatedAt
    }
}
