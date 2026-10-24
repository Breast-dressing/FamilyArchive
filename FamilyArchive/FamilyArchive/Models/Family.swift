//
//  Family.swift
//  FamilyArchive
//

import Foundation
import SwiftData

/// A family added from a family URL. The URL itself is the identity of the
/// family (matching the `family_key = url` convention of the reference code),
/// so adding the same link twice updates the existing entry instead of
/// creating a duplicate.
@Model
final class Family {
    @Attribute(.unique) var url: String
    var name: String
    var familyID: String
    var avatarURL: String
    /// 家族签名（QQ 音乐 Announcement）
    var signature: String = ""
    /// API 返回的格式化总荣誉值，例如 "2026.8万+"
    var honor: String = ""
    /// API 返回的周排名
    var weekRank: String = ""
    /// API 返回的成员数文本，例如 "30"
    var memberCountText: String = ""
    /// API 返回的 PK 胜场
    var pkWins: String = ""
    var createdAt: Date

    init(
        url: String,
        name: String,
        familyID: String = "",
        avatarURL: String = "",
        signature: String = "",
        honor: String = "",
        weekRank: String = "",
        memberCountText: String = "",
        pkWins: String = "",
        createdAt: Date = .now
    ) {
        self.url = url
        self.name = name
        self.familyID = familyID
        self.avatarURL = avatarURL
        self.signature = signature
        self.honor = honor
        self.weekRank = weekRank
        self.memberCountText = memberCountText
        self.pkWins = pkWins
        self.createdAt = createdAt
    }
}
