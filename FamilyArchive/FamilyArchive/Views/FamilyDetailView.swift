//
//  FamilyDetailView.swift
//  FamilyArchive
//
//  Family detail. The detached "＋" tab opens a multi-file picker while this
//  page is on screen (see RootView.handlePlusButtonTapped).
//

import Foundation
import SwiftData
import SwiftUI

struct FamilyDetailView: View {
    let familyURL: String

    @Query private var families: [Family]
    @Query private var allMembers: [FamilyMember]
    @Query private var allRecords: [HonorRecord]

    private var family: Family? {
        families.first { $0.url == familyURL }
    }

    private var members: [FamilyMember] {
        allMembers
            .filter { $0.familyURL == familyURL }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var familyRecordCount: Int {
        allRecords.filter { $0.familyURL == familyURL }.count
    }

    var body: some View {
        Group {
            if family == nil {
                ContentUnavailableView(
                    "Family not found",
                    systemImage: "person.3",
                    description: Text("This family is no longer stored.")
                )
            } else {
                List {
                    headerSection

                    if members.isEmpty {
                        Section {
                            Text("No member data for this family yet. Add the family link again to load its members.")
                                .foregroundStyle(.secondary)
                        } header: {
                            Text("Members")
                        }
                    } else {
                        ForEach(members) { member in
                            memberSection(for: member)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(family?.name ?? "Family")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(familyURL)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                Text("\(members.count) members · \(familyRecordCount) records")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func memberSection(for member: FamilyMember) -> some View {
        let records = records(for: member)

        Section {
            if records.isEmpty {
                Text("No records yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    HonorRecordRow(record: record)
                }
            }
        } header: {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(member.name)
                    .font(.subheadline.weight(.semibold))

                Text(member.memberID)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(records.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func records(for member: FamilyMember) -> [HonorRecord] {
        allRecords
            .filter { $0.memberID == member.memberID && $0.familyURL == familyURL }
            .sorted { $0.time > $1.time }
    }
}

struct HonorRecordRow: View {
    let record: HonorRecord

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.taskName.isEmpty ? "—" : record.taskName)

                Text(record.time.isEmpty ? "—" : record.time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(record.honorValue)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.tint)
        }
        .padding(.vertical, 2)
    }
}
