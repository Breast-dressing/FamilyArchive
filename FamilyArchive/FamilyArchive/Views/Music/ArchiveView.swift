import SwiftData
import SwiftUI

struct ArchiveView: View {
    @Query(sort: \Family.createdAt, order: .reverse) private var families: [Family]
    @Query private var members: [FamilyMember]
    @Query private var records: [HonorRecord]

    private let columns = [
        GridItem(.adaptive(minimum: 158), spacing: 12)
    ]

    var body: some View {
        List {
            Section("徽章") {
                Text("暂无徽章")
                    .foregroundStyle(.secondary)
            }

            Section("家族") {
                if families.isEmpty {
                    Text("还没有家族。复制家族链接后，点击 ＋ → 家族。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(families) { family in
                            NavigationLink(value: family.url) {
                                FamilyCard(
                                    family: family,
                                    totalHonor: totalHonor(for: family),
                                    memberCount: memberCount(for: family)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }

            Section("卡片") {
                Text("暂无卡片")
                    .foregroundStyle(.secondary)
            }

            Section("商务") {
                Text("暂无商务内容")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func totalHonor(for family: Family) -> Int {
        HonorValueParser.total(for: records.filter { $0.familyURL == family.url })
    }

    private func memberCount(for family: Family) -> Int {
        members.filter { $0.familyURL == family.url }.count
    }
}

private struct FamilyCard: View {
    let family: Family
    let totalHonor: Int
    let memberCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RemoteAvatarView(
                    urlString: family.avatarURL,
                    systemImage: "person.3.fill",
                    size: 46
                )
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Text(family.name.isEmpty ? "未命名家族" : family.name)
                .font(.headline)
                .lineLimit(1)

            Text("总荣誉值 \(totalHonor)")
                .font(.subheadline)
                .foregroundStyle(.tint)

            Text("\(memberCount) 位成员")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }
}
