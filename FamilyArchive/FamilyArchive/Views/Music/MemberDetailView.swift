import Foundation
import SwiftData
import SwiftUI

struct MemberDetailView: View {
    let familyURL: String
    let memberID: String

    @Environment(\.modelContext) private var modelContext
    @Environment(PendingImportStore.self) private var pendingImports

    @Query private var members: [FamilyMember]
    @Query private var records: [HonorRecord]
    @Query private var families: [Family]

    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var summaryMessage = ""
    @State private var showSummary = false

    private var member: FamilyMember? {
        members.first { $0.memberID == memberID && $0.familyURL == familyURL }
    }

    private var familyName: String {
        families.first { $0.url == familyURL }?.name ?? "家族"
    }

    private var memberRecords: [HonorRecord] {
        records.filter { $0.memberID == memberID && $0.familyURL == familyURL }
    }

    private var pending: PendingHARImport? {
        pendingImports.pending(for: familyURL)
    }

    private var pendingRecords: [ParsedHonorRecord] {
        guard let pending, let member else { return [] }
        return pending.outcome.records.filter {
            MemberNameResolver.matches($0.memberName, memberName: member.name)
        }
    }

    private var filteredRecords: [HonorRecord] {
        let filter = DateRangeFilter(start: startDate, end: endDate)
        return memberRecords
            .filter { filter.matches(timeString: $0.time) }
            .sorted { $0.time > $1.time }
    }

    var body: some View {
        Group {
            if let member {
                list(member: member)
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
        .alert("提示", isPresented: $showSummary) {
            Button("好", role: .cancel) {}
        } message: {
            Text(summaryMessage)
        }
    }

    private func list(member: FamilyMember) -> some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    RemoteAvatarView(
                        urlString: member.avatarURL,
                        systemImage: "person.crop.circle.fill",
                        size: 64
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(member.name)
                            .font(.title3.bold())
                        Text(familyName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("成员编号 \(member.memberID)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("总荣誉值 \(HonorValueParser.total(for: memberRecords))")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                        Text("\(memberRecords.count) 条记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            if let pending {
                PendingImportPreview(
                    pending: pending,
                    records: pendingRecords,
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
                            HonorRecordRow(record: record)
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy(duration: 0.35), value: pending?.id)
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
