import Foundation

enum MemberHonorDisplay {
    /// Mirrors the Python rule:
    /// - if the selected date range has records, show their sum;
    /// - otherwise show the unconsumed API honor (`apiHonor - all stored records`).
    static func total(
        apiHonor: Int,
        filteredRecords: [HonorRecord],
        allRecords: [HonorRecord],
        hasAnyRecordInRange: Bool
    ) -> Int {
        if hasAnyRecordInRange {
            return HonorValueParser.total(for: filteredRecords)
        }
        let stored = HonorValueParser.total(for: allRecords)
        return max(0, apiHonor - stored)
    }
}
