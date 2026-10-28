import SwiftData
import SwiftUI
import UIKit

struct ArchiveView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\Family.sortOrder),
        SortDescriptor(\Family.createdAt, order: .reverse)
    ])
    private var families: [Family]

    @State private var displayedFamilies: [Family] = []
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
                sectionLink(
                    title: "乐迷",
                    subtitle: "勋章皮肤分类与解锁状态",
                    systemImage: "person.2.fill",
                    route: .fans
                )

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
                            NavigationLink(value: MusicRoute.family(family.url)) {
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
                        }
                    }
                    .padding(.horizontal, 16)
                    .reorderContainer(for: Family.self) { difference in
                        applyReorder(difference)
                    }
                }

                sectionLink(
                    title: "勋章",
                    subtitle: "勋章馆分类、模块与获得状态",
                    systemImage: "medal.fill",
                    route: .medals
                )

                sectionLink(
                    title: "卡牌",
                    subtitle: "歌词卡、卡面与实体编号",
                    systemImage: "rectangle.stack.fill",
                    route: .cards
                )
            }
            .padding(.vertical, 8)
        }
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
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

    private func sectionLink(
        title: String,
        subtitle: String,
        systemImage: String,
        route: MusicRoute
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(
                        Color(uiColor: .tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    private func applyReorder(
        _ difference: ReorderDifference<
            Family.ID,
            ReorderableSingleCollectionIdentifier
        >
    ) {
        let sources = Set(difference.sources)
        let moving = displayedFamilies.filter { sources.contains($0.id) }
        guard !moving.isEmpty else { return }

        var remaining = displayedFamilies.filter { !sources.contains($0.id) }
        switch difference.destination.position {
        case .end:
            remaining.append(contentsOf: moving)
        case .before(let destinationID):
            if let index = remaining.firstIndex(where: { $0.id == destinationID }) {
                remaining.insert(contentsOf: moving, at: index)
            } else {
                remaining.append(contentsOf: moving)
            }
        }

        displayedFamilies = remaining
        persistOrder()
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
