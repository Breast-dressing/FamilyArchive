//
//  MusicQueryStore.swift
//  FamilyArchive
//
//  Lightweight persistence for "query every music account" results. The music
//  modules keep their history in UserDefaults so the saved summaries survive
//  launches without changing the SwiftData schema.
//

import Foundation
import Observation

struct MusicQueryRecord: Identifiable, Codable, Hashable {
    static let badgeKind = "badge"
    static let medalKind = "medal"

    let id: UUID
    let kind: String
    let accountName: String
    let encUin: String
    let date: Date
    let summary: String

    init(
        id: UUID = UUID(),
        kind: String,
        accountName: String,
        encUin: String,
        date: Date = .now,
        summary: String
    ) {
        self.id = id
        self.kind = kind
        self.accountName = accountName
        self.encUin = encUin
        self.date = date
        self.summary = summary
    }
}

@Observable
final class MusicQueryStore {
    private static let storageKey = "music.query.records"
    private static let maxRecords = 100

    private let defaults: UserDefaults
    private(set) var records: [MusicQueryRecord]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.records = Self.load(from: defaults)
    }

    func records(for kind: String) -> [MusicQueryRecord] {
        records.filter { $0.kind == kind }
    }

    func save(kind: String, accountName: String, encUin: String, summary: String) {
        records.insert(
            MusicQueryRecord(
                kind: kind,
                accountName: accountName,
                encUin: encUin,
                summary: summary
            ),
            at: 0
        )
        if records.count > Self.maxRecords {
            records.removeLast(records.count - Self.maxRecords)
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    private static func load(from defaults: UserDefaults) -> [MusicQueryRecord] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MusicQueryRecord].self, from: data) else {
            return []
        }
        return decoded
    }
}
