//
//  MemberNameResolver.swift
//  FamilyArchive
//
//  Resolves a HAR member name to a member of the *current family context*.
//  The specification says: skip the record and show a warning when the member
//  cannot be found or when the name is ambiguous. No member is ever created.
//

import Foundation

enum MemberNameResolver {
    enum Resolution {
        case resolved(memberID: String)
        case notFound
        case ambiguous
    }

    static func resolve(_ rawName: String, in members: [FamilyMember]) -> Resolution {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !members.isEmpty else { return .notFound }

        // 1. Exact (case-insensitive) name match.
        let exactMatches = members.filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(name) == .orderedSame
        }
        if exactMatches.count == 1 {
            return .resolved(memberID: exactMatches[0].memberID)
        }
        if exactMatches.count > 1 {
            return .ambiguous
        }

        // 2. Fallback that ignores trailing punctuation on the stored name.
        //    HAR member names have their trailing punctuation removed by the
        //    parsing pipeline, but the stored QQ Music member name may still
        //    contain it (e.g. "姜黎非." vs "姜黎非").
        let normalizedName = normalizedForMatching(name)
        guard !normalizedName.isEmpty else { return .notFound }
        let normalizedMatches = members.filter {
            normalizedForMatching($0.name) == normalizedName
        }
        if normalizedMatches.count == 1 {
            return .resolved(memberID: normalizedMatches[0].memberID)
        }
        if normalizedMatches.count > 1 {
            return .ambiguous
        }
        return .notFound
    }

    private static func normalizedForMatching(_ value: String) -> String {
        var result = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var didTrim = true
        while didTrim {
            didTrim = false
            if let last = result.last,
               last.unicodeScalars.allSatisfy({
                   CharacterSet.punctuationCharacters.contains($0)
                       || CharacterSet.whitespacesAndNewlines.contains($0)
               }) {
                result.removeLast()
                didTrim = true
            }
        }
        return result
    }
}
