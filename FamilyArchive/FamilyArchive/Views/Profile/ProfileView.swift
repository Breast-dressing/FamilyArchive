import SwiftData
import SwiftUI

/// 个人页（原「更多」）：个人信息卡 + 家族小卡片 + 卡牌 / 勋章入口。
struct ProfileView: View {
    @Query(sort: [
        SortDescriptor(\Family.sortOrder),
        SortDescriptor(\Family.createdAt, order: .reverse)
    ])
    private var families: [Family]

    @Query(sort: \UserProfile.updatedAt) private var profiles: [UserProfile]

    @State private var isAccountsPresented = false
    @Namespace private var accountsNamespace

    private var profile: UserProfile? {
        profiles.first
    }

    private var familyColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 10),
            count: ProfileLayout.familyColumns(for: families.count)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    profileCard
                    familySection
                    entryRow
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationTitle("个人")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAccountsPresented = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .matchedTransitionSource(
                        id: AccountsTransitionSource.profile,
                        in: accountsNamespace
                    )
                    .accessibilityLabel("账号")
                }
            }
            .sheet(isPresented: $isAccountsPresented) {
                AccountsView(scope: nil)
                    .navigationTransition(
                        .zoom(
                            sourceID: AccountsTransitionSource.profile,
                            in: accountsNamespace
                        )
                    )
            }
            .navigationDestination(for: MusicRoute.self) { route in
                switch route {
                case .family(let familyURL):
                    FamilyDetailView(familyURL: familyURL)
                case .member(let familyURL, let memberID):
                    MemberDetailView(familyURL: familyURL, memberID: memberID)
                case .fans:
                    FansSkinsView()
                case .medals:
                    MedalHallView()
                case .cards:
                    LyricCardsView()
                }
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                DataImageView(
                    data: profile?.avatarData,
                    systemImage: "person.crop.circle.fill",
                    size: 64,
                    cornerRadius: 32
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.title3.bold())
                    Text(displaySignature)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            NavigationLink(value: MusicRoute.fans) {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                    Text("乐迷")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    .quaternary.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private var displayName: String {
        let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "我的" : name
    }

    private var displaySignature: String {
        let signature = profile?.signature.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return signature.isEmpty ? "还没有签名" : signature
    }

    private var familySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("家族")
                .font(.title3.bold())

            if families.isEmpty {
                Text("还没有家族。点击下方 ＋ → 家族，粘贴家族链接即可添加。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: familyColumns, alignment: .leading, spacing: 10) {
                    ForEach(families) { family in
                        NavigationLink(value: MusicRoute.family(family.url)) {
                            familyTile(family)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func familyTile(_ family: Family) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(family.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
            Text(family.honor)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(
            .quaternary.opacity(0.5),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var entryRow: some View {
        HStack(spacing: 12) {
            entryCard(
                title: "卡牌",
                subtitle: "歌词卡与编号",
                systemImage: "rectangle.stack",
                route: .cards
            )
            entryCard(
                title: "勋章",
                subtitle: "勋章馆与获得状态",
                systemImage: "rosette",
                route: .medals
            )
        }
    }

    private func entryCard(
        title: String,
        subtitle: String,
        systemImage: String,
        route: MusicRoute
    ) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .medium))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .background(
                .quaternary.opacity(0.5),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}
