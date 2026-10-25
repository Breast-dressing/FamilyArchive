import Foundation
import SwiftData
import SwiftUI
import UIKit

struct MemberDetailView: View {
    let familyURL: String
    let memberID: String

    @Environment(PendingImportStore.self) private var pendingImports
    @Environment(DateFilterStore.self) private var dateFilter
    @Environment(RootAccessoryState.self) private var accessoryState

    @Query private var members: [FamilyMember]
    @Query private var records: [HonorRecord]
    @Query private var families: [Family]

    private var member: FamilyMember? {
        members.first { $0.memberID == memberID && $0.familyURL == familyURL }
    }

    private var familyName: String {
        families.first { $0.url == familyURL }?.name ?? "家族"
    }

    private var familyRecords: [HonorRecord] {
        records.filter { $0.familyURL == familyURL }
    }

    private var filteredFamilyRecords: [HonorRecord] {
        familyRecords.filter { dateFilter.filter.matches(timeString: $0.time) }
    }

    private var hasAnyRecordInRange: Bool {
        !filteredFamilyRecords.isEmpty
    }

    private var memberRecords: [HonorRecord] {
        familyRecords
            .filter { $0.memberID == memberID }
            .sorted { $0.time > $1.time }
    }

    private var filteredMemberRecords: [HonorRecord] {
        filteredFamilyRecords
            .filter { $0.memberID == memberID }
            .sorted { $0.time > $1.time }
    }

    private var totalHonor: Int {
        guard let member else { return 0 }
        return MemberHonorDisplay.total(
            apiHonor: member.apiHonor,
            filteredRecords: filteredMemberRecords,
            allRecords: memberRecords,
            hasAnyRecordInRange: hasAnyRecordInRange
        )
    }

    private var pending: PendingHARImport? {
        pendingImports.pending(for: familyURL)
    }

    private var dateGroups: [RecordDateGroup] {
        let groups = Dictionary(grouping: filteredMemberRecords) {
            DateDisplay.dayKey(from: $0.time)
        }
        return groups
            .map { RecordDateGroup(id: $0.key, records: $0.value) }
            .sorted { $0.id > $1.id }
    }

    var body: some View {
        Group {
            if let member {
                detailList(member: member)
            } else {
                ContentUnavailableView(
                    "成员不存在",
                    systemImage: "person.crop.circle",
                    description: Text("请返回家族重新选择成员。")
                )
            }
        }
        .navigationTitle(member?.name ?? "成员")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailList(member: FamilyMember) -> some View {
        List {
            Section("成员信息") {
                memberInfoCard(member)
            }

            Section("荣誉记录") {
                if filteredMemberRecords.isEmpty {
                    Text("暂无记录")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ForEach(dateGroups) { group in
                        NavigationLink {
                            DailyRecordsView(date: group.id, records: group.records)
                        } label: {
                            dateGroupRow(group)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.bottom, 76, for: .scrollContent)
        .onAppear {
            updateAccessory(member: member)
        }
        .onChange(of: dateFilter.label) { _, _ in
            updateAccessory(member: member)
        }
        .onChange(of: pending?.id) { _, _ in
            updateAccessory(member: member)
        }
    }

    private func memberInfoCard(_ member: FamilyMember) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                RemoteAvatarView(
                    urlString: member.avatarURL,
                    systemImage: "person.crop.circle.fill",
                    size: 66
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(member.name)
                        .font(.title3.bold())
                        .lineLimit(1)

                    if !member.medalLevel.isEmpty || !member.nameplate.isEmpty {
                        HStack(spacing: 6) {
                            if !member.medalLevel.isEmpty {
                                Text(member.medalLevel)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Color(uiColor: .tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    )
                            }
                            if !member.nameplate.isEmpty {
                                Text(member.nameplate)
                                    .font(.caption.bold())
                                    .foregroundStyle(Color(uiColor: .systemBrown))
                            }
                        }
                    }

                    Text(familyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(totalHonor)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text("总荣誉")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Divider()
                    .frame(height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(filteredMemberRecords.count)")
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                    Text("记录数")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dateGroupRow(_ group: RecordDateGroup) -> some View {
        let total = group.total
        return HStack(spacing: 8) {
            Text(group.id)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Spacer()
            Text("\(group.records.count) 条")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(total > 0 ? "+\(total)" : "\(total)")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .frame(minWidth: 56, alignment: .trailing)
        }
    }

    private func updateAccessory(member: FamilyMember) {
        accessoryState.enterMember(
            name: member.name,
            familyURL: familyURL,
            dateLabel: dateFilter.label,
            pendingCount: pending?.outcome.records.count ?? 0
        )
    }
}

private struct RecordDateGroup: Identifiable {
    let id: String
    let records: [HonorRecord]

    var total: Int {
        HonorValueParser.total(for: records)
    }
}

struct DailyRecordsView: View {
    let date: String
    let records: [HonorRecord]

    var body: some View {
        List {
            Section(date) {
                ForEach(records) { record in
                    HonorRecordRow(record: record)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(date)
        .navigationBarTitleDisplayMode(.inline)
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
