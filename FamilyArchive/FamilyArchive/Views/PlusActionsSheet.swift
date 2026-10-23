import SwiftUI

enum ArchiveAction: String, CaseIterable, Identifiable {
    case badges = "徽章"
    case family = "家族"
    case cards = "卡片"
    case business = "商务"

    var id: String { rawValue }
    var title: String { rawValue }

    var systemImage: String {
        switch self {
        case .badges:
            return "rosette"
        case .family:
            return "person.3"
        case .cards:
            return "creditcard"
        case .business:
            return "briefcase"
        }
    }
}

struct PlusActionsSheet: View {
    let route: PlusRoute
    let onArchiveAction: (ArchiveAction) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                switch route {
                case .archiveActions:
                    List {
                        Section {
                            ForEach(ArchiveAction.allCases) { action in
                                Button {
                                    dismiss()
                                    onArchiveAction(action)
                                } label: {
                                    Label(action.title, systemImage: action.systemImage)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                            }
                        }
                    }

                case .unavailable(let pageName):
                    ContentUnavailableView(
                        "暂无可添加内容",
                        systemImage: "plus.circle",
                        description: Text("当前页面（\(pageName)）没有可用的 ＋ 操作。")
                    )
                }
            }
            .navigationTitle("添加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
