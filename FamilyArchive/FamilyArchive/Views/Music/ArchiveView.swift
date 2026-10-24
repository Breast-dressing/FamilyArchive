import SwiftData
import SwiftUI
import UIKit

struct ArchiveView: View {
    @Query(sort: \Family.createdAt, order: .reverse) private var families: [Family]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        List {
            Section("徽章") {
                Text("暂无徽章")
                    .foregroundStyle(.secondary)
            }

            Section("家族信息") {
                if families.isEmpty {
                    Text("还没有家族。复制家族链接后，点击 ＋ → 家族。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(families) { family in
                            NavigationLink(value: family.url) {
                                FamilyCard(family: family)
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
}

private struct FamilyCard: View {
    let family: Family

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                RemoteAvatarView(
                    urlString: family.avatarURL,
                    systemImage: "person.3.fill",
                    size: 66
                )
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            Text(family.name.isEmpty ? "未命名家族" : family.name)
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)

            if !family.honor.isEmpty {
                Text("荣誉 \(family.honor)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .aspectRatio(5 / 3, contentMode: .fit)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }
}
