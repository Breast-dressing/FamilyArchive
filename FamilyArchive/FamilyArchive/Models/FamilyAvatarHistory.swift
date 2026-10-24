import Foundation
import SwiftData

@Model
final class FamilyAvatarHistory {
    @Attribute(.unique) var id: UUID
    var familyURL: String
    var avatarURL: String
    var startDate: Date
    var endDate: Date?

    init(
        id: UUID = UUID(),
        familyURL: String,
        avatarURL: String,
        startDate: Date = .now,
        endDate: Date? = nil
    ) {
        self.id = id
        self.familyURL = familyURL
        self.avatarURL = avatarURL
        self.startDate = startDate
        self.endDate = endDate
    }
}
