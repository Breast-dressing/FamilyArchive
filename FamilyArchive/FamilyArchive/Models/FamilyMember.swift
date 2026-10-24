//
//  FamilyMember.swift
//  FamilyArchive
//

import Foundation
import SwiftData

/// A member of a family. `memberID` is the unique identifier for stored member
/// data, exactly as required by the specification.
@Model
final class FamilyMember {
    @Attribute(.unique) var memberID: String
    var name: String
    var avatarURL: String
    var familyURL: String
    /// 勋章等级，例如 "V132"
    var medalLevel: String = ""
    /// 铭牌，例如 "NO.5203831"
    var nameplate: String = ""
    /// API 返回的成员总荣誉值；HAR 没有该日期范围记录时用于计算剩余荣誉
    var apiHonor: Int = 0

    init(
        memberID: String,
        name: String,
        avatarURL: String = "",
        familyURL: String,
        medalLevel: String = "",
        nameplate: String = "",
        apiHonor: Int = 0
    ) {
        self.memberID = memberID
        self.name = name
        self.avatarURL = avatarURL
        self.familyURL = familyURL
        self.medalLevel = medalLevel
        self.nameplate = nameplate
        self.apiHonor = apiHonor
    }
}
