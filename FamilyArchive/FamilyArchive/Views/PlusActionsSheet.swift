//
//  PlusActionsSheet.swift
//  FamilyArchive
//
//  The option list presented by the detached "＋" tab. It never navigates and
//  never changes the selected tab.
//

import SwiftUI

enum ArchiveAction: String, CaseIterable, Identifiable {
    case badges = "Badges"
    case family = "Family"
    case cards = "Cards"
    case business = "Business"

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
                        "No actions here",
                        systemImage: "plus.circle",
                        description: Text("The ＋ button has no actions on \(pageName).")
                    )
                }
            }
            .navigationTitle("Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
