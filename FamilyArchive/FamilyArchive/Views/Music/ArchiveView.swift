import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\Family.sortOrder),
        SortDescriptor(\Family.createdAt, order: .reverse)
    ])
    private var families: [Family]

    @State private var displayedFamilies: [Family] = []
    @State private var draggedURL: String?
    @State private var leaderFamily: Family?
    @State private var avatarFamily: Family?
    @State private var deleteFamily: Family?
    @State private var showDeleteConfirmation = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("家族信息")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)

                if displayedFamilies.isEmpty {
                    Text("还没有家族。复制家族链接后，点击 ＋ → 家族。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 60)
                        .padding(.horizontal, 16)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(displayedFamilies) { family in
                            NavigationLink(value: family.url) {
                                FamilyCard(family: family)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    leaderFamily = family
                                } label: {
                                    Label("添加族长", systemImage: "person.badge.plus")
                                }

                                Button {
                                    avatarFamily = family
                                } label: {
                                    Label("更改头像", systemImage: "photo")
                                }

                                Button(role: .destructive) {
                                    deleteFamily = family
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("删除家族", systemImage: "trash")
                                }
                            }
                            .onDrag {
                                draggedURL = family.url
                                return NSItemProvider(object: family.url as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: FamilyDropDelegate(
                                    target: family,
                                    families: $displayedFamilies,
                                    draggedURL: $draggedURL,
                                    persist: persistOrder
                                )
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.vertical, 8)
        }
        .contentMargins(.bottom, 76, for: .scrollContent)
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            displayedFamilies = families
        }
        .onChange(of: families.map(\.url)) { _, _ in
            displayedFamilies = families
        }
        .sheet(item: $leaderFamily) { family in
            LeaderPickerView(family: family)
        }
        .sheet(item: $avatarFamily) { family in
            NavigationStack {
                AvatarHistoryView(family: family)
            }
        }
        .alert("提示", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {
                deleteFamily = nil
            }
            Button("删除", role: .destructive) {
                if let family = deleteFamily {
                    delete(family)
                }
            }
        } message: {
            Text("确定要删除该家族吗？")
        }
    }

    private func persistOrder() {
        for (index, family) in displayedFamilies.enumerated() {
            family.sortOrder = index
        }
        try? modelContext.save()
    }

    private func delete(_ family: Family) {
        let url = family.url
        let members = (try? modelContext.fetch(FetchDescriptor<FamilyMember>())) ?? []
        let records = (try? modelContext.fetch(FetchDescriptor<HonorRecord>())) ?? []
        let histories = (try? modelContext.fetch(FetchDescriptor<FamilyAvatarHistory>())) ?? []

        for member in members where member.familyURL == url {
            modelContext.delete(member)
        }
        for record in records where record.familyURL == url {
            modelContext.delete(record)
        }
        for history in histories where history.familyURL == url {
            modelContext.delete(history)
        }
        modelContext.delete(family)
        try? modelContext.save()

        deleteFamily = nil
        displayedFamilies = families
    }
}

private struct FamilyDropDelegate: DropDelegate {
    let target: Family
    @Binding var families: [Family]
    @Binding var draggedURL: String?
    let persist: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedURL,
              let from = families.firstIndex(where: { $0.url == draggedURL }),
              let to = families.firstIndex(where: { $0.url == target.url }),
              from != to else { return }

        var updated = families
        updated.move(
            fromOffsets: IndexSet(integer: from),
            toOffset: to > from ? to + 1 : to
        )
        withAnimation(.snappy(duration: 0.3)) {
            families = updated
        }
        persist()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedURL = nil
        persist()
        return true
    }
}

private struct FamilyCard: View {
    let family: Family

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RemoteAvatarView(
                urlString: family.avatarURL,
                systemImage: "person.3.fill",
                size: 56
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(family.name.isEmpty ? "未命名家族" : family.name)
                    .font(.headline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                if !family.honor.isEmpty {
                    Text("荣誉 \(family.honor)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}
