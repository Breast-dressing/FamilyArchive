import Foundation
import Observation

struct PendingHARImport: Identifiable {
    let id: UUID
    let familyURL: String
    let outcome: HARImportOutcome
    let createdAt: Date
}

@Observable
final class PendingImportStore {
    private var pendingByFamily: [String: PendingHARImport] = [:]

    var hasPending: Bool { !pendingByFamily.isEmpty }

    func pending(for familyURL: String) -> PendingHARImport? {
        pendingByFamily[familyURL]
    }

    func setPending(_ outcome: HARImportOutcome, for familyURL: String) {
        pendingByFamily[familyURL] = PendingHARImport(
            id: UUID(),
            familyURL: familyURL,
            outcome: outcome,
            createdAt: .now
        )
    }

    func clear(for familyURL: String) {
        pendingByFamily.removeValue(forKey: familyURL)
    }
}
