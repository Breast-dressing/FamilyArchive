import Foundation
import SwiftData
import SwiftUI

struct FamilyDetailView: View {
    let familyURL: String

    @Environment(\.modelContext) private var modelContext
    @Environment(PendingImportStore.self) private var pendingImports

    @Query private var families: [Family]
    @Query private var allMembers: [FamilyMember]
    @Query private var allRecords: [HonorRecord]

    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var summaryMessage = ""
    @State private var showSummary = false

    private var family: Family? {
        families.first { $0.url == familyURL }
    }

    private var members: [FamilyMember] {
        allMembers
            .filter { $0.familyURL == familyURL }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var familyRecords: [HonorRecord] {
        allRecords.filter { $0.familyURL == familyURL }
    }

    private var pending: PendingHARImport? {
        pendingImports.pending(for: familyURL)
    }

    private var filteredRecords: [HonorRecord] {
        let filter = DateRangeFilter(start: startDate, end: endDate)
        return familyRecords
            .filter { filter.matches(timeString: $0.time) }
            .sorted { $0.time > $1.time }
    }

    private var memberNames: [String: String] {
        Dictionary(uniqueKeysWithValues: members.map { ($0.memberID, $0.name) })
    }

    var body: some View {
        Group {
            if let family {
                list(family: family)
            } else {
                ContentUnavailableView(
                    "家族不存在",
                    systemImage: "person.3",
                    description: Text("请返回档案重新选择家族。")
                )
            }
        }
        .navigationTitle(family?.name ?? "家族")
        .navigationBarTitleDisplayMode(.inline)
        .alert("提示", isPresented: $showSummary) {
            Button("好", role: .cancel) {}
        } message: {
            Text(summaryMessage)
        }
    }

    private func list(family: Family) -> some View {
        List {
            headerSection(family: family)

            if let pending {
                PendingImportPreview(
                    pending: pending,
                    records: pending.outcome.records,
                    onSave: { savePending(pending) },
                    onCancel: { pendingImports.clear(for: familyURL) }
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    )
                )
            } else {
                DateFilterSection(
                    startDate: $startDate,
                    endDate: $endDate,
                    totalCount: filteredRecords.count
                )
                .transition(.opacity)

                Section("记录") {
                    if filteredRecords.isEmpty {
                        Text("暂无记录")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(filteredRecords) { record in
                            HonorRecordRow(
                                record: record,
                                memberName: memberNames[record.memberID]
                            )
                        }
                    }
                }
                .transition(.opacity)
            }

            Section("成员") {
                if members.isEmpty {
                    Text("暂无成员数据。重新添加家族链接可加载成员。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(members) { member in
                        NavigationLink {
                            MemberDetailView(
                                familyURL: familyURL,
                                memberID: member.memberID
                            )
                        } label: {
                            memberRow(member)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy(duration: 0.35), value: pending?.id)
    }

    private func headerSection(family: Family) -> some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                RemoteAvatarView(
                    urlString: family.avatarURL,
                    systemImage: "person.3.fill",
                    size: 64
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(family.name.isEmpty ? "未命名家族" : family.name)
                        .font(.title3.bold())

                    if !family.familyID.isEmpty {
                        Text("家族编号 \(family.familyID)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("总荣誉值 \(HonorValueParser.total(for: familyRecords))")
                        .font(.subheadline)
                        .foregroundStyle(.tint)

                    Text("\(members.count) 位成员 · \(familyRecords.count) 条记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            Text(family.url)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private func memberRow(_ member: FamilyMember) -> some View {
        let records = familyRecords.filter { $0.memberID == member.memberID }
        return HStack(spacing: 12) {
            RemoteAvatarView(
                urlString: member.avatarURL,
                systemImage: "person.crop.circle.fill",
                size: 42
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.body)
                Text(member.memberID)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(HonorValueParser.total(for: records))")
                    .font(.subheadline)
                    .foregroundStyle(.tint)
                Text("\(records.count) 条")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func savePending(_ pending: PendingHARImport) {
        let summary = HARImportWriter.save(pending, in: modelContext)
        if summary.saveError == nil {
            pendingImports.clear(for: familyURL)
        }
        summaryMessage = summaryText(summary)
        showSummary = true
    }

    private func summaryText(_ summary: HARImportSummary) -> String {
        var lines = ["已保存 \(summary.imported) 条记录。"]
        if !summary.notFound.isEmpty {
            lines.append("未找到成员：\(summary.notFound.joined(separator: "、"))")
        }
        if !summary.ambiguous.isEmpty {
            lines.append("成员名不明确：\(summary.ambiguous.joined(separator: "、"))")
        }
        lines.append(contentsOf: summary.warnings)
        if let saveError = summary.saveError {
            lines.append("保存失败：\(saveError)")
        }
        return lines.joined(separator: "\n")
    }
}

struct HonorRecordRow: View {
    let record: HonorRecord
    var memberName: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(record.taskName.isEmpty ? "—" : record.taskName)

                HStack(spacing: 4) {
                    if let memberName, !memberName.isEmpty {
                        Text(memberName)
                        Text("·")
                    }
                    Text(record.time.isEmpty ? "—" : record.time)
                }
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
