import SwiftData
import SwiftUI

struct FansSkinsView: View {
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]

    @State private var queryStore = MusicQueryStore()
    @State private var selectedAccountID: UUID?
    @State private var encUin = ""
    @State private var startSequence = 100
    @State private var endSequence = 300
    @State private var skins: [BadgeSkin] = []
    @State private var isLoading = false
    @State private var progressText = ""
    @State private var errorMessage = ""
    @State private var selectedSkin: BadgeSkin?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var musicAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.music.rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                inputCard

                if isLoading {
                    ProgressView(progressText.isEmpty ? "正在获取皮肤…" : progressText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if !errorMessage.isEmpty {
                    ContentUnavailableView(
                        "获取失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if skins.isEmpty {
                    ContentUnavailableView(
                        "暂无皮肤",
                        systemImage: "sparkles",
                        description: Text("选择音乐账号或输入 enc_uin，然后查询勋章皮肤。")
                    )
                    .padding(.vertical, 30)
                } else {
                    Text("皮肤 \(skins.count)")
                        .font(.headline)
                        .padding(.horizontal, 16)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(skins) { skin in
                            Button {
                                selectedSkin = skin
                            } label: {
                                skinCard(skin)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }

                savedHistory
            }
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .navigationTitle("乐迷")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selectedSkin) { skin in
            BadgeSkinDetailView(skin: skin)
        }
        .onChange(of: selectedAccountID) { _, newValue in
            guard let newValue,
                  let account = musicAccounts.first(where: { $0.id == newValue }) else {
                return
            }
            encUin = account.username
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("勋章皮肤")
                .font(.headline)

            if !musicAccounts.isEmpty {
                Picker("音乐账号", selection: $selectedAccountID) {
                    Text("手动输入").tag(UUID?.none)
                    ForEach(musicAccounts) { account in
                        Text(account.username).tag(Optional(account.id))
                    }
                }
                .pickerStyle(.menu)
            }

            TextField("enc_uin", text: $encUin)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack(spacing: 10) {
                TextField("开始", value: $startSequence, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)

                Text("至")
                    .foregroundStyle(.secondary)

                TextField("结束", value: $endSequence, format: .number)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
            }
            .font(.subheadline)

            Button {
                Task { await load(uin: encUin, summaryFor: nil) }
            } label: {
                Text("获取皮肤")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || encUin.isEmpty)

            if !musicAccounts.isEmpty {
                Button {
                    Task { await loadAllAccounts() }
                } label: {
                    Text("查询全部音乐账号并保存")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var savedHistory: some View {
        let records = Array(queryStore.records(for: MusicQueryRecord.badgeKind).prefix(5))
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("已保存查询")
                    .font(.headline)

                ForEach(records) { record in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.seal")
                            .foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.accountName)
                                .font(.subheadline.bold())
                            Text(record.summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(record.date, format: .dateTime.month().day().hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .padding(.horizontal, 16)
        }
    }

    private func skinCard(_ skin: BadgeSkin) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImage(url: URL(string: skin.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit()
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .overlay {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(height: 96)
                .frame(maxWidth: .infinity)
                .background(
                    Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                Text(skin.stateText)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        skin.isUnlocked ? Color.green.opacity(0.15) : Color.orange.opacity(0.15),
                        in: Capsule()
                    )
                    .foregroundStyle(skin.isUnlocked ? .green : .orange)
                    .padding(6)
            }

            Text(skin.name)
                .font(.caption.bold())
                .lineLimit(2)
                .foregroundStyle(.primary)
        }
    }

    private func load(uin: String, summaryFor accountName: String?) async {
        guard !uin.isEmpty else { return }
        isLoading = true
        progressText = ""
        errorMessage = ""
        skins = []
        let sequences = BadgeSkinService.querySequences(start: startSequence, end: endSequence)
        let fetched = await BadgeSkinService.fetchSkins(uin: uin, sequences: sequences)
        skins = fetched
        if fetched.isEmpty {
            errorMessage = "没有获取到皮肤，请检查 enc_uin 或编号范围。"
        } else if let accountName {
            queryStore.save(
                kind: MusicQueryRecord.badgeKind,
                accountName: accountName,
                encUin: uin,
                summary: "皮肤 \(fetched.count) 个，范围 \(sequences.first ?? 0)–\(sequences.last ?? 0)"
            )
        }
        isLoading = false
    }

    private func loadAllAccounts() async {
        isLoading = true
        progressText = ""
        errorMessage = ""
        skins = []
        let sequences = BadgeSkinService.querySequences(start: startSequence, end: endSequence)
        var collected: [BadgeSkin] = []
        var savedCount = 0

        for (index, account) in musicAccounts.enumerated() {
            progressText = "正在查询 \(index + 1)/\(musicAccounts.count)：\(account.username)"
            let fetched = await BadgeSkinService.fetchSkins(
                uin: account.username,
                sequences: sequences
            )
            collected.append(contentsOf: fetched)
            if !fetched.isEmpty {
                savedCount += 1
                queryStore.save(
                    kind: MusicQueryRecord.badgeKind,
                    accountName: account.username,
                    encUin: account.username,
                    summary: "皮肤 \(fetched.count) 个，范围 \(sequences.first ?? 0)–\(sequences.last ?? 0)"
                )
            }
        }

        progressText = ""
        skins = collected
        if savedCount == 0 {
            errorMessage = "所有音乐账号都没有获取到皮肤。"
        }
        isLoading = false
    }
}

private struct BadgeSkinDetailView: View {
    let skin: BadgeSkin
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AsyncImage(url: URL(string: skin.imageURL)) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFit()
                        } else {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(height: 220)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(skin.name)
                            .font(.title2.bold())
                        Label(skin.stateText, systemImage: skin.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundStyle(skin.isUnlocked ? .green : .orange)
                        if !skin.unlockDate.isEmpty {
                            Label("解锁时间：\(skin.unlockDate)", systemImage: "calendar")
                        }
                        Label("使用人数：\(skin.userCount)", systemImage: "person.2")
                        if !skin.unlockTask.isEmpty {
                            Label("解锁任务：\(skin.unlockTask)", systemImage: "checklist")
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationTitle("皮肤详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }
}
