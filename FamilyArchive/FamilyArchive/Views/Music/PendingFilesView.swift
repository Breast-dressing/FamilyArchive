import SwiftData
import SwiftUI

/// App Store style, fully opaque pending files sheet. The list chrome is
/// hidden so the adaptive `systemBackground` color is the only backdrop.
struct PendingFilesView: View {
    let familyURL: String
    let memberName: String?

    @Environment(PendingImportStore.self) private var pendingImports
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var summaryMessage = ""
    @State private var saveSucceeded = false
    @State private var showSummary = false

    private var pending: PendingHARImport? {
        pendingImports.pending(for: familyURL)
    }

    private var records: [ParsedHonorRecord] {
        guard let pending else { return [] }
        if let memberName, !memberName.isEmpty {
            return pending.outcome.records.filter {
                MemberNameResolver.matches($0.memberName, memberName: memberName)
            }
        }
        return pending.outcome.records
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pending {
                    List {
                        PendingImportPreview(
                            pending: pending,
                            records: records,
                            onSave: { save(pending) },
                            onCancel: {
                                pendingImports.clear(for: familyURL)
                                dismiss()
                            }
                        )
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
                } else {
                    ContentUnavailableView(
                        "暂无待保存文件",
                        systemImage: "tray",
                        description: Text("请先选择并解析记录文件。")
                    )
                }
            }
            .navigationTitle("待保存文件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
        .presentationBackground(Color(uiColor: .systemBackground))
        .alert("提示", isPresented: $showSummary) {
            Button(saveSucceeded ? "完成" : "好") {
                if saveSucceeded {
                    dismiss()
                }
            }
        } message: {
            Text(summaryMessage)
        }
    }

    private func save(_ pending: PendingHARImport) {
        let summary = HARImportWriter.save(pending, in: modelContext)
        if summary.saveError == nil {
            pendingImports.clear(for: familyURL)
        }
        saveSucceeded = summary.saveError == nil
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
