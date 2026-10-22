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
    var createdAt: Date

    init(
        url: String,
        name: String,
        familyID: String = "",
        avatarURL: String = "",
        createdAt: Date = .now
    ) {
        self.url = url
        self.name = name
        self.familyID = familyID
        self.avatarURL = avatarURL
        self.createdAt = createdAt
    }
}
