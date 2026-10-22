//
//  ArchiveView.swift
//  FamilyArchive
//
//  Music -> Archive. Exactly four sections, in this order:
//  Badges, Family, Cards, Business.
//

import SwiftData
import SwiftUI

struct ArchiveView: View {
    @Query(sort: \Family.name) private var families: [Family]
    @Query private var members: [FamilyMember]

    var body: some View {
        List {
            Section {
                Text("No badges yet")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Badges")
                    .textCase(nil)
            }

            Section {
                if families.isEmpty {
                    Text("No families yet. Copy a family link, then tap ＋ → Family.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(families) { family in
                        NavigationLink(value: family.url) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(family.name)

                                Text(family.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)

                                Text(memberCountText(for: family))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } header: {
                Text("Family")
                    .textCase(nil)
            }

            Section {
                Text("No cards yet")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Cards")
                    .textCase(nil)
            }

            Section {
                Text("No business yet")
                    .foregroundStyle(.secondary)
            } header: {
                Text("Business")
                    .textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func memberCountText(for family: Family) -> String {
        let count = members.filter { $0.familyURL == family.url }.count
        return count == 1 ? "1 member" : "\(count) members"
    }
}
