import SwiftUI

struct FamilyImportActionsView: View {
    let familyURL: String

    @Environment(FileImportCoordinator.self) private var importCoordinator
    @Environment(PendingImportStore.self) private var pendingImports
    @Environment(\.dismiss) private var dismiss

    private var pending: PendingHARImport? {
        pendingImports.pending(for: familyURL)
    }

    var body: some View {
        List {
            Section("导入家族记录") {
                Button {
                    requestImport()
                } label: {
                    Label("选择记录文件", systemImage: "doc.badge.plus")
                }
            }

            if let pending {
                Section("待保存文件") {
                    Text("\(pending.outcome.fileCount) 个文件 · \(pending.outcome.records.count) 条记录")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("添加")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func requestImport() {
        dismiss()
        Task { @MainActor in
            // Let the zoom pop finish before the system file importer appears.
            try? await Task.sleep(for: .milliseconds(300))
            importCoordinator.requestHARImport(for: familyURL)
        }
    }
}
