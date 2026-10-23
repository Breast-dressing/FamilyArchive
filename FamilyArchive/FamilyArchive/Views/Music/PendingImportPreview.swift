import SwiftUI

struct PendingImportPreview: View {
    let pending: PendingHARImport
    let records: [ParsedHonorRecord]
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var isFilesExpanded = true
    @State private var isRecordsExpanded = false

    private struct MemberCount: Identifiable {
        let id: String
        let count: Int
    }

    private var groupedByMember: [MemberCount] {
        Dictionary(grouping: records, by: \.memberName)
            .map { MemberCount(id: $0.key, count: $0.value.count) }
            .sorted { $0.id < $1.id }
    }

    var body: some View {
        Group {
            Section("文件预览") {
                DisclosureGroup(isExpanded: $isFilesExpanded) {
                    if pending.outcome.fileNames.isEmpty {
                        Text("没有文件。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pending.outcome.fileNames, id: \.self) { name in
                            Label(name, systemImage: "doc.text")
                                .font(.caption)
                        }
                    }

                    Text("有效文件 \(pending.outcome.fileCount) 个 · 解析记录 \(records.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(groupedByMember) { item in
                        HStack {
                            Text(item.id)
                            Spacer()
                            Text("\(item.count) 条")
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                } label: {
                    Label("待保存文件", systemImage: "tray.and.arrow.down")
                }
            }

            if !pending.outcome.warnings.isEmpty {
                Section("提示") {
                    ForEach(pending.outcome.warnings, id: \.self) { warning in
                        Text(warning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("待保存记录") {
                DisclosureGroup(isExpanded: $isRecordsExpanded) {
                    if records.isEmpty {
                        Text("没有可保存的记录。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(records.indices, id: \.self) { index in
                            let record = records[index]
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.taskName)
                                    .lineLimit(2)
                                Text("\(record.memberName) · \(record.time)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(record.honorValue)
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                } label: {
                    Label("查看解析记录（\(records.count)）", systemImage: "list.bullet.rectangle")
                }
            }

            Section {
                Button("保存文件") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)

                Button("取消", role: .cancel) {
                    onCancel()
                }
            }
        }
        .animation(.snappy, value: isFilesExpanded)
        .animation(.snappy, value: isRecordsExpanded)
    }
}
