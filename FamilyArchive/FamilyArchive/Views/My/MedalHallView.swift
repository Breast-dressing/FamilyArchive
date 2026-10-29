import SwiftData
import SwiftUI

struct MedalHallView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]
    @Query(sort: \MedalTabRecord.tabID) private var storedTabs: [MedalTabRecord]

    @State private var selectedAccountID: UUID?
    @State private var selectedTabID: Int?
    @State private var isLoading = false
    @State private var errorMessage = ""

    private var musicAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.music.rawValue && !$0.encUin.isEmpty }
    }

    private var selectedAccount: Account? {
        if let selectedAccountID, let match = musicAccounts.first(where: { $0.id == selectedAccountID }) {
            return match
        }
        return musicAccounts.first
    }

    private var tabs: [MedalTabRecord] {
        guard let encUin = selectedAccount?.encUin else { return [] }
        return storedTabs.filter { $0.encUin == encUin }
    }

    private var currentModules: [MedalModule] {
        guard let tab = tabs.first(where: { $0.tabID == selectedTabID }) ?? tabs.first,
              let data = tab.modulesJSON.data(using: .utf8),
              let modules = try? JSONDecoder().decode([MedalModule].self, from: data) else {
            return []
        }
        return modules
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if musicAccounts.isEmpty {
                    ContentUnavailableView(
                        "还没有音乐账号",
                        systemImage: "music.note",
                        description: Text("请先在账号页添加带有 ID 的音乐账号。")
                    )
                    .padding(.vertical, 30)
                } else if isLoading {
                    ProgressView("正在查询勋章…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if !errorMessage.isEmpty {
                    ContentUnavailableView(
                        "查询失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if tabs.isEmpty {
                    ContentUnavailableView(
                        "勋章馆",
                        systemImage: "medal",
                        description: Text("正在等待勋章数据。")
                    )
                    .padding(.vertical, 30)
                } else {
                    ForEach(currentModules) { module in
                        moduleCard(module)
                    }
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("勋章")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if tabs.count > 1 {
                    Picker("分类", selection: Binding(
                        get: { selectedTabID ?? tabs.first?.tabID ?? 0 },
                        set: { selectedTabID = $0 }
                    )) {
                        ForEach(tabs) { tab in
                            Text(tab.title).tag(tab.tabID)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(minWidth: 220)
                } else {
                    Text("勋章")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(musicAccounts) { account in
                        Button("\(account.username) · \(account.encUin)") {
                            selectedAccountID = account.id
                            Task { await load(account) }
                        }
                    }
                    Button("全部账号查询") {
                        Task { await loadAll() }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .task {
            if let account = selectedAccount, tabs.isEmpty {
                await load(account)
            } else if selectedTabID == nil {
                selectedTabID = tabs.first?.tabID
            }
        }
    }

    private func moduleCard(_ module: MedalModule) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(module.name).font(.headline)
            if module.medals.isEmpty {
                Text("暂无勋章").font(.footnote).foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10)
                    ],
                    spacing: 10
                ) {
                    ForEach(module.medals.prefix(6)) { medal in
                        VStack(spacing: 6) {
                            AsyncImage(url: URL(string: medal.imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit()
                                } else {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color(uiColor: .tertiarySystemFill))
                                }
                            }
                            .frame(height: 62)
                            Text(medal.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .foregroundStyle(medal.isObtained ? .primary : .secondary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private func store(_ snapshot: MedalHallSnapshot, account: Account) {
        var existing: [Int: MedalTabRecord] = [:]
        for record in storedTabs where record.encUin == account.encUin {
            existing[record.tabID] = record
        }
        for tab in snapshot.tabs {
            let payload = "[" + tab.modules.map { $0.encodedJSON() }.joined(separator: ",") + "]"
            if let record = existing[tab.id] {
                record.title = tab.title
                record.modulesJSON = payload
                record.updatedAt = .now
            } else {
                modelContext.insert(
                    MedalTabRecord(
                        encUin: account.encUin,
                        accountID: account.id,
                        memberID: account.username,
                        tabID: tab.id,
                        title: tab.title,
                        modulesJSON: payload
                    )
                )
            }
        }
        try? modelContext.save()
        if selectedTabID == nil { selectedTabID = snapshot.tabs.first?.id }
    }

    private func load(_ account: Account) async {
        guard !account.encUin.isEmpty else { return }
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        do {
            let snapshot = try await MedalHallService.load(
                urlString: MedalHallService.urlString(encUin: account.encUin),
                encUin: account.encUin
            )
            store(snapshot, account: account)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadAll() async {
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        for account in musicAccounts {
            do {
                let snapshot = try await MedalHallService.load(
                    urlString: MedalHallService.urlString(encUin: account.encUin),
                    encUin: account.encUin
                )
                store(snapshot, account: account)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
