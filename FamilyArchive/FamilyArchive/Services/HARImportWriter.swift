import Foundation
import SwiftData

struct HARImportSummary {
    let imported: Int
    let notFound: [String]
    let ambiguous: [String]
    let warnings: [String]
    let saveError: String?

    var hasIssues: Bool {
        !notFound.isEmpty || !ambiguous.isEmpty || saveError != nil
    }
}

enum HARImportWriter {
    @MainActor
    static func save(_ pending: PendingHARImport, in context: ModelContext) -> HARImportSummary {
        let storedMembers = (try? context.fetch(FetchDescriptor<FamilyMember>())) ?? []
        let familyMembers = storedMembers.filter { $0.familyURL == pending.familyURL }

        var imported = 0
        var notFound = Set<String>()
        var ambiguous = Set<String>()

        for record in pending.outcome.records {
            switch MemberNameResolver.resolve(record.memberName, in: familyMembers) {
            case .resolved(let memberID):
                let honorRecord = HonorRecord(
                    memberID: memberID,
                    taskName: record.taskName,
                    honorValue: record.honorValue,
                    time: record.time,
                    familyURL: pending.familyURL
                )
                context.insert(honorRecord)
                imported += 1
            case .notFound:
                notFound.insert(record.memberName)
            case .ambiguous:
                ambiguous.insert(record.memberName)
            }
        }

        var saveError: String?
        do {
            try context.save()
        } catch {
            saveError = error.localizedDescription
            context.rollback()
        }

        return HARImportSummary(
            imported: saveError == nil ? imported : 0,
            notFound: notFound.sorted(),
            ambiguous: ambiguous.sorted(),
            warnings: pending.outcome.warnings,
            saveError: saveError
        )
    }
}
