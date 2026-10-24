import Foundation
import Observation

@Observable
final class FamilyAccessoryState {
    var isVisible = false
    var familyURL: String?
    var memberName: String?
    var dateLabel = ""
    var pendingCount = 0
    var isDateFilterPresented = false
    var isPendingFilesPresented = false

    func show(
        familyURL: String,
        memberName: String?,
        dateLabel: String,
        pendingCount: Int
    ) {
        self.familyURL = familyURL
        self.memberName = memberName
        self.dateLabel = dateLabel
        self.pendingCount = pendingCount
        self.isVisible = true
    }

    func hide() {
        isVisible = false
        familyURL = nil
        memberName = nil
        pendingCount = 0
        isDateFilterPresented = false
        isPendingFilesPresented = false
    }
}
