import Foundation
import SwiftData
import SwiftUI
import UIKit

struct FamilyDetailView: View {
    let familyURL: String

    @Environment(PendingImportStore.self) private var pendingImports
    @Environment(DateFilterStore.self) private var dateFilter
    @Environment(RootAccessoryState.self) private var accessoryState

    @Query private var families: [Family]
    @Query private var allMembers: [FamilyMember]
    @Query private var allRecords: [HonorRecord]

    @State private var sharePayload: FamilySharePayload?
    @State private var shareAvatar: UIImage?

    private var family: Family? {
        families.first { $0.url == familyURL }
    }

    private var familyRecords: [HonorRecord] {
        allRecords.filter { $0.familyURL == familyURL }
    }

    private var filteredRecords: [HonorRecord] {
        familyRecords
            .filter { dateFilter.filter.matches(timeString: $0.time) }
            .sorted { $0.time > $1.time }
    }

    private var hasAnyRecordInRange: Bool {
        !filteredRecords.isEmpty
    }

    private var members: [FamilyMember] {
        allMembers
            .filter { $0.familyURL == familyURL }
            .sorted {
                let left = displayHonor($0)
                let right = displayHonor($1)
                if left != right { return left > right }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private var familyMemberTotal: Int {
        members.reduce(0) { $0 + displayHonor($1) }
    }

    private var pending: PendingHARImport? {
        pendingImports.pending(for: familyURL)
    }

    var body: some View {
        Group {
            if let family {
                detailList(family: family)
            } else {
                ContentUnavailableView(
                    "家族不存在",
                    systemImage: "person.3",
                    description: Text("请返回档案重新选择家族。")
                )
            }
        }
        .navigationTitle(family?.name ?? "家族")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .background(
            FamilySharePresenter(payload: $sharePayload) {
                sharePayload = nil
            }
            .frame(width: 0, height: 0)
        )
    }

    private func detailList(family: Family) -> some View {
        List {
            Section("家族信息") {
                familyInfoCard(family)
            }

            Section {
                memberSummaryRow

                if members.isEmpty {
                    Text("暂无成员数据。重新添加家族链接可加载成员。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(members) { member in
                        NavigationLink(
                            value: MusicRoute.member(
                                familyURL: familyURL,
                                memberID: member.memberID
                            )
                        ) {
                            memberRow(member)
                        }
                    }
                }
            } header: {
                Text("成员列表 · \(members.count) 人")
            }
        }
        .listStyle(.insetGrouped)
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    sharePayload = makeSharePayload(family: family)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("分享家族")
            }
        }
        .onAppear {
            updateAccessory()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-UIPreviewShare") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.2))
                    sharePayload = makeSharePayload(family: family)
                }
            }
            if ProcessInfo.processInfo.arguments.contains("-UIPreviewShareImage") {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.2))
                    let payload = makeSharePayload(family: family)
                    guard let image = FamilyHonorImageRenderer.image(for: payload),
                          let data = image.pngData(),
                          let documents = FileManager.default.urls(
                              for: .documentDirectory,
                              in: .userDomainMask
                          ).first else { return }
                    try? data.write(
                        to: documents.appendingPathComponent("family-honor-export.png")
                    )
                }
            }
            #endif
        }
        .onChange(of: dateFilter.label) { _, _ in
            updateAccessory()
        }
        .onChange(of: pending?.id) { _, _ in
            updateAccessory()
        }
        .task(id: family.avatarURL) {
            await loadShareAvatar(family.avatarURL)
        }
    }

    private func familyInfoCard(_ family: Family) -> some View {
        let memberCount = family.memberCountText.isEmpty
            ? "\(members.count)"
            : family.memberCountText
        let stats: [(value: String, label: String)] = [
            (family.honor, "总荣誉值"),
            (family.weekRank, "周排名"),
            (memberCount, "成员"),
            (family.pkWins, "PK胜场")
        ].filter { !$0.value.isEmpty }

        return HStack(alignment: .top, spacing: 12) {
            RemoteAvatarView(
                urlString: family.avatarURL,
                systemImage: "person.3.fill",
                size: 84
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(family.name.isEmpty ? "未命名家族" : family.name)
                    .font(.title2.bold())
                    .lineLimit(1)

                if !stats.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(stats.indices, id: \.self) { index in
                            if index > 0 {
                                Spacer(minLength: 8)
                            }
                            VStack(spacing: 2) {
                                Text(stats[index].value)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                                Text(stats[index].label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                if !family.signature.isEmpty {
                    Text(family.signature)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var memberSummaryRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(familyMemberTotal)")
                .font(.subheadline.bold())
                .foregroundStyle(.primary)
            Text("总荣誉值")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func memberRow(_ member: FamilyMember) -> some View {
        HStack(spacing: 10) {
            RemoteAvatarView(
                urlString: member.avatarURL,
                systemImage: "person.crop.circle.fill",
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                MemberBadgeRow(
                    medalLevel: member.medalLevel,
                    nameplate: member.nameplate
                )

                Text("\(displayHonor(member))荣誉值")
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private var leaderName: String {
        guard let family else { return "暂无族长" }
        return members.first { $0.memberID == family.leaderMemberID }?.name ?? "暂无族长"
    }

    private func makeSharePayload(family: Family) -> FamilySharePayload {
        FamilySharePayload(
            familyName: family.name.isEmpty ? "家族" : family.name,
            familyURL: URL(string: familyURL),
            leaderName: leaderName,
            period: dateFilter.label,
            members: members.map {
                FamilyShareMember(
                    id: $0.memberID,
                    name: $0.name,
                    honor: displayHonor($0)
                )
            },
            avatar: shareAvatar
        )
    }

    private func loadShareAvatar(_ urlString: String) async {
        guard !urlString.isEmpty,
              let url = URL(string: urlString),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else {
            shareAvatar = nil
            return
        }
        shareAvatar = image
    }

    private func updateAccessory() {
        accessoryState.enterFamily(
            familyURL: familyURL,
            dateLabel: dateFilter.accessoryLabel,
            pendingCount: pending?.outcome.records.count ?? 0
        )
    }

    private func displayHonor(_ member: FamilyMember) -> Int {
        let allMemberRecords = familyRecords.filter { $0.memberID == member.memberID }
        let filteredMemberRecords = filteredRecords.filter { $0.memberID == member.memberID }
        return MemberHonorDisplay.total(
            apiHonor: member.apiHonor,
            filteredRecords: filteredMemberRecords,
            allRecords: allMemberRecords,
            hasAnyRecordInRange: hasAnyRecordInRange
        )
    }
}
