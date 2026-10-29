import SwiftData
import SwiftUI

/// 乐迷：按账号 ID (enc_uin) 自动扫描勋章皮肤，按 CategID 分组，组名由用户命名。
struct FansSkinsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]
    @Query(sort: \BadgeSkinRecord.sequence) private var records: [BadgeSkinRecord]
    @Query private var queryStates: [BadgeQueryState]

    @State private var selectedAccountID: UUID?
    @State private var isScanning = false
    @State private var progressText = ""
    @State private var errorMessage = ""
    @State private var groupNames: [String: String] = [:]
    @State private var selectedSkin: BadgeSkinRecord?

    private var musicAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.music.rawValue && !$0.encUin.isEmpty }
    }

    private var selectedAccount: Account? {
        if let selectedAccountID, let match = musicAccounts.first(where: { $0.id == selectedAccountID }) {
            return match
        }
        return musicAccounts.first
    }

    private var visibleRecords: [BadgeSkinRecord] {
        guard let encUin = selectedAccount?.encUin else { return [] }
        return records.filter { $0.encUin == encUin }
    }

    private var groupedRecords: [(key: String, items: [BadgeSkinRecord])] {
        Dictionary(grouping: visibleRecords, by: \.categKey)
            .map { (key: $0.key, items: $0.value.sorted { $0.sequence < $1.sequence }) }
            .sorted { $0.key < $1.key }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if isScanning {
                    ProgressView(progressText.isEmpty ? "正在查询勋章皮肤…" : progressText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if !errorMessage.isEmpty {
                    ContentUnavailableView(
                        "查询失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if groupedRecords.isEmpty {
                    ContentUnavailableView(
                        "暂无皮肤",
                        systemImage: "sparkles",
                        description: Text("请先在账号页添加带有 ID 的音乐账号。")
                    )
                    .padding(.vertical, 30)
                } else {
                    ForEach(groupedRecords, id: \.key) { group in
                        groupSection(group)
                    }
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .navigationTitle("乐迷")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedSkin) { record in
            BadgeSkinDetailView(record: record)
        }
        .task {
            loadGroupNames()
            if let account = selectedAccount {
                await incrementalScan(for: account)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if musicAccounts.isEmpty {
                Text("还没有音乐账号，请先在账号页添加。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Picker("音乐账号", selection: Binding(
                    get: { selectedAccount?.id },
                    set: { newValue in
                        selectedAccountID = newValue
                        if let account = selectedAccount {
                            Task { await incrementalScan(for: account) }
                        }
                    }
                )) {
                    ForEach(musicAccounts) { account in
                        Text("\(account.username) · \(account.encUin)").tag(Optional(account.id))
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("皮肤 \(visibleRecords.count) 个")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("全部账号查询") {
                        Task { await scanAllAccounts(full: false) }
                    }
                    .font(.footnote)
                    .disabled(isScanning)
                    Button("重新扫描") {
                        Task { await scanAllAccounts(full: true) }
                    }
                    .font(.footnote)
                    .disabled(isScanning)
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

    private func groupSection(_ group: (key: String, items: [BadgeSkinRecord])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("分组名称", text: Binding(
                get: { groupNames[group.key] ?? "" },
                set: { newValue in
                    groupNames[group.key] = newValue
                    updateGroupName(newValue, for: group.key)
                }
            ))
            .font(.headline)
            .textFieldStyle(.plain)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(group.items) { record in
                    Button {
                        selectedSkin = record
                    } label: {
                        skinCard(record)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .padding(.horizontal, 16)
    }

    private func skinCard(_ record: BadgeSkinRecord) -> some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: record.imageURL)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                }
            }
            .frame(height: 78)

            Text(record.name)
                .font(.caption2.bold())
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Storage

    private func loadGroupNames() {
        var names: [String: String] = [:]
        for record in visibleRecords where !record.groupName.isEmpty {
            names[record.categKey] = record.groupName
        }
        groupNames = names
    }

    private func updateGroupName(_ name: String, for key: String) {
        for record in visibleRecords where record.categKey == key {
            record.groupName = name
        }
        try? modelContext.save()
    }

    private func queryState(for account: Account) -> BadgeQueryState? {
        queryStates.first { $0.encUin == account.encUin }
    }

    private func store(_ skins: [BadgeSkin], for account: Account) {
        var existing: [String: BadgeSkinRecord] = [:]
        for record in (try? modelContext.fetch(FetchDescriptor<BadgeSkinRecord>())) ?? []
        where record.encUin == account.encUin {
            existing[record.key] = record
        }

        for skin in skins {
            let key = "\(account.encUin)-\(skin.id)"
            if let record = existing[key] {
                record.sequence = skin.sequence
                record.name = skin.name
                record.imageURL = skin.imageURL
                record.isUnlocked = skin.isUnlocked
                record.stateText = skin.stateText
                record.unlockDate = skin.unlockDate
                record.userCount = skin.userCount
                record.unlockTask = skin.unlockTask
                record.backgroundColorHex = skin.backgroundColorHex
                record.categID = skin.categID
                record.updatedAt = .now
            } else {
                let record = BadgeSkinRecord(
                    encUin: account.encUin,
                    accountID: account.id,
                    memberID: account.username,
                    skin: skin
                )
                modelContext.insert(record)
            }
        }
        try? modelContext.save()
    }

    private func updateState(lastSequence: Int, for account: Account) {
        if let state = queryState(for: account) {
            state.lastSequence = max(state.lastSequence, lastSequence)
            state.updatedAt = .now
        } else {
            modelContext.insert(
                BadgeQueryState(
                    encUin: account.encUin,
                    accountID: account.id,
                    memberID: account.username,
                    lastSequence: lastSequence
                )
            )
        }
        try? modelContext.save()
    }

    // MARK: - Query

    private func chunk(_ sequences: [Int], uin: String) async -> [BadgeSkin] {
        var found: [BadgeSkin] = []
        await withTaskGroup(of: (Int, BadgeSkin?).self) { group in
            var iterator = sequences.makeIterator()
            var launched = 0
            while launched < 10, let seq = iterator.next() {
                group.addTask { (seq, await BadgeSkinService.fetchSkin(uin: uin, sequence: seq)) }
                launched += 1
            }
            while let (_, skin) = await group.next() {
                if let skin { found.append(skin) }
                if let seq = iterator.next() {
                    group.addTask { (seq, await BadgeSkinService.fetchSkin(uin: uin, sequence: seq)) }
                }
            }
        }
        return found.sorted { $0.sequence < $1.sequence }
    }

    private func fullScan(for account: Account) async {
        var sequence = 1
        var consecutiveEmpty = 0
        var lastSequence = 0

        while consecutiveEmpty < 50, sequence <= 3000 {
            progressText = "正在扫描序号 \(sequence)…"
            let window = Array(sequence..<min(sequence + 10, 3001))
            let found = await chunk(window, uin: account.encUin)
            store(found, for: account)

            let foundSet = Set(found.map(\.sequence))
            for value in window {
                if foundSet.contains(value) {
                    consecutiveEmpty = 0
                    lastSequence = max(lastSequence, value)
                } else {
                    consecutiveEmpty += 1
                }
                if consecutiveEmpty >= 50 { break }
            }
            sequence += 10
            updateState(lastSequence: lastSequence, for: account)
        }
        progressText = ""
    }

    private func incrementalScan(for account: Account) async {
        guard !isScanning else { return }
        isScanning = true
        progressText = ""
        errorMessage = ""
        defer { isScanning = false }

        let state = queryState(for: account)
        if state == nil {
            await fullScan(for: account)
        } else {
            let start = max(1, (state?.lastSequence ?? 0) + 1)
            progressText = "正在增量查询 \(start)–\(start + 19)…"
            let found = await chunk(Array(start..<(start + 20)), uin: account.encUin)
            if let last = found.map(\.sequence).max() {
                store(found, for: account)
                updateState(lastSequence: last, for: account)
            }
            progressText = ""
        }
        loadGroupNames()
    }

    private func scanAllAccounts(full: Bool) async {
        guard !isScanning else { return }
        isScanning = true
        errorMessage = ""
        defer { isScanning = false }

        for account in musicAccounts {
            progressText = "正在查询 \(account.username)…"
            if full {
                await fullScan(for: account)
            } else {
                let state = queryState(for: account)
                if state == nil {
                    await fullScan(for: account)
                } else {
                    let start = max(1, (state?.lastSequence ?? 0) + 1)
                    let found = await chunk(Array(start..<(start + 20)), uin: account.encUin)
                    if let last = found.map(\.sequence).max() {
                        store(found, for: account)
                        updateState(lastSequence: last, for: account)
                    }
                }
            }
        }
        progressText = ""
        loadGroupNames()
    }
}

private struct BadgeSkinDetailView: View {
    let record: BadgeSkinRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    AsyncImage(url: URL(string: record.imageURL)) { phase in
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
                        Text(record.name).font(.title2.bold())
                        Label(record.stateText, systemImage: record.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                            .foregroundStyle(record.isUnlocked ? .green : .orange)
                        if !record.unlockDate.isEmpty {
                            Label("解锁时间：\(record.unlockDate)", systemImage: "calendar")
                        }
                        Label("使用人数：\(record.userCount)", systemImage: "person.2")
                        if !record.unlockTask.isEmpty {
                            Label("解锁任务：\(record.unlockTask)", systemImage: "checklist")
                        }
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
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
