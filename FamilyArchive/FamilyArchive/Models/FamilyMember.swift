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

    init(
        memberID: String,
        name: String,
        avatarURL: String = "",
        familyURL: String
    ) {
        self.memberID = memberID
        self.name = name
        self.avatarURL = avatarURL
        self.familyURL = familyURL
    }
}
