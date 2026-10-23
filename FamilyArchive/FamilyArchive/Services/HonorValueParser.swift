import Foundation

enum HonorValueParser {
    /// HAR honor values look like "+60荣誉值"; keep the sign and digits.
    static func integer(from value: String) -> Int {
        let filtered = value.filter { $0.isNumber || $0 == "-" || $0 == "+" }
        return Int(filtered) ?? 0
    }

    static func total(for records: [HonorRecord]) -> Int {
        records.reduce(0) { $0 + integer(from: $1.honorValue) }
    }

    static func total(for records: [HonorRecord], memberID: String) -> Int {
        total(for: records.filter { $0.memberID == memberID })
    }
}
