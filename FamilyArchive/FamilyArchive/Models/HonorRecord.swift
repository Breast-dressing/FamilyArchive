//
//  HonorRecord.swift
//  FamilyArchive
//

import Foundation
import SwiftData

/// A record parsed from a HAR file.
///
/// The stored model intentionally has exactly the five fields required by the
/// specification. There is no relationship property: records are linked to the
/// member through `memberID` and to the family through `familyURL`.
@Model
final class HonorRecord {
    var memberID: String
    var taskName: String
    var honorValue: String
    var time: String
    var familyURL: String

    init(
        memberID: String,
        taskName: String,
        honorValue: String,
        time: String,
        familyURL: String
    ) {
        self.memberID = memberID
        self.taskName = taskName
        self.honorValue = honorValue
        self.time = time
        self.familyURL = familyURL
    }
}
