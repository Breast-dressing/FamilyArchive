//
//  MusicQueryModels.swift
//  FamilyArchive
//
//  Persistent results for the 乐迷 (badge skins) and 勋章 (medal hall) modules.
//  Records are keyed by the account's enc_uin and stay attached to that account.
//

import Foundation
import SwiftData

@Model
final class BadgeSkinRecord {
    @Attribute(.unique) var key: String
    var encUin: String
    var accountID: UUID
    var memberID: String
    var skinID: String
    var sequence: Int
    var name: String
    var imageURL: String
    var isUnlocked: Bool
    var stateText: String
    var unlockDate: String
    var userCount: Int
    var unlockTask: String
    var backgroundColorHex: String
    var categID: String
    /// 用户自定义分组名，默认为空（不内置任何默认组名）。
    var groupName: String = ""
    var updatedAt: Date

    init(
        encUin: String,
        accountID: UUID,
        memberID: String,
        skin: BadgeSkin,
        updatedAt: Date = .now
    ) {
        self.key = "\(encUin)-\(skin.id)"
        self.encUin = encUin
        self.accountID = accountID
        self.memberID = memberID
        self.skinID = skin.id
        self.sequence = skin.sequence
        self.name = skin.name
        self.imageURL = skin.imageURL
        self.isUnlocked = skin.isUnlocked
        self.stateText = skin.stateText
        self.unlockDate = skin.unlockDate
        self.userCount = skin.userCount
        self.unlockTask = skin.unlockTask
        self.backgroundColorHex = skin.backgroundColorHex
        self.categID = skin.categID
        self.updatedAt = updatedAt
    }

    var categKey: String { categID.isEmpty ? "unknown" : categID }
}

@Model
final class BadgeQueryState {
    @Attribute(.unique) var encUin: String
    var accountID: UUID
    var memberID: String
    /// 最后一个有皮肤数据的序号。
    var lastSequence: Int
    var updatedAt: Date

    init(
        encUin: String,
        accountID: UUID,
        memberID: String,
        lastSequence: Int = 0,
        updatedAt: Date = .now
    ) {
        self.encUin = encUin
        self.accountID = accountID
        self.memberID = memberID
        self.lastSequence = lastSequence
        self.updatedAt = updatedAt
    }
}

@Model
final class MedalTabRecord {
    @Attribute(.unique) var key: String
    var encUin: String
    var accountID: UUID
    var memberID: String
    var tabID: Int
    var title: String
    var modulesJSON: String
    var updatedAt: Date

    init(
        encUin: String,
        accountID: UUID,
        memberID: String,
        tabID: Int,
        title: String,
        modulesJSON: String,
        updatedAt: Date = .now
    ) {
        self.key = "\(encUin)-\(tabID)"
        self.encUin = encUin
        self.accountID = accountID
        self.memberID = memberID
        self.tabID = tabID
        self.title = title
        self.modulesJSON = modulesJSON
        self.updatedAt = updatedAt
    }
}

extension MedalModule {
    func encodedJSON() -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

extension MedalModule: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, scheme, hasNext, medals
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        scheme = try c.decode(String.self, forKey: .scheme)
        hasNext = try c.decode(Bool.self, forKey: .hasNext)
        medals = try c.decode([MedalItem].self, forKey: .medals)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(scheme, forKey: .scheme)
        try c.encode(hasNext, forKey: .hasNext)
        try c.encode(medals, forKey: .medals)
    }
}

extension MedalItem: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, name, imageURL, level, createTime, isObtained
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        imageURL = try c.decode(String.self, forKey: .imageURL)
        level = try c.decode(Int.self, forKey: .level)
        createTime = try c.decode(String.self, forKey: .createTime)
        isObtained = try c.decode(Bool.self, forKey: .isObtained)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(imageURL, forKey: .imageURL)
        try c.encode(level, forKey: .level)
        try c.encode(createTime, forKey: .createTime)
        try c.encode(isObtained, forKey: .isObtained)
    }
}
