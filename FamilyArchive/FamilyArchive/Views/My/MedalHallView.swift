import SwiftData
import SwiftUI

struct MedalHallView: View {
    @Query(sort: \Account.createdAt, order: .reverse) private var accounts: [Account]

    @State private var queryStore = MusicQueryStore()
    @State private var urlString = MedalHallService.fixedURLString
    @State private var snapshot: MedalHallSnapshot?
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var selectedModule: MedalModule?

    private var musicAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.music.rawValue }
    }

    private var modules: [MedalModule] {
        guard let snapshot, snapshot.tabs.indices.contains(selectedTab) else { return [] }
        return snapshot.tabs[selectedTab].modules
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                inputCard

                if isLoading {
                    ProgressView("正在解析勋章馆…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if !errorMessage.isEmpty {
                    ContentUnavailableView(
                        "解析失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if let snapshot {
                    if snapshot.tabs.count > 1 {
                        Picker("分类", selection: $selectedTab) {
                            ForEach(snapshot.tabs.indices, id: \.self) { index in
                                Text(snapshot.tabs[index].title)
                                    .tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                    }

                    if modules.isEmpty {
                        ContentUnavailableView(
                            "暂无勋章",
                            systemImage: "medal",
                            description: Text("该分类暂时没有可展示的勋章。")
                        )
                        .padding(.vertical, 30)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(modules) { module in
                                moduleCard(module)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                } else {
                    ContentUnavailableView(
                        "勋章馆",
                        systemImage: "medal",
                        description: Text("粘贴勋章馆链接后开始解析。")
                    )
                    .padding(.vertical, 30)
                }

                savedHistory
            }
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .navigationTitle("勋章")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .sheet(item: $selectedModule) { module in
            MedalModuleDetailView(module: module)
        }
    }

    @ViewBuilder
    private var savedHistory: some View {
        let records = Array(queryStore.records(for: MusicQueryRecord.medalKind).prefix(5))
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

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("勋章馆")
                .font(.headline)

            TextField("粘贴勋章馆链接", text: $urlString, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                Task { await load(accountName: nil) }
            } label: {
                Text("开始解析")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || urlString.isEmpty)

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

    private func moduleCard(_ module: MedalModule) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(module.name)
                    .font(.headline)
                Spacer()
                if module.hasNext {
                    Button("查看更多") {
                        selectedModule = module
                    }
                    .font(.footnote)
                }
            }

            if module.medals.isEmpty {
                Text("暂无勋章")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                        medalCell(medal)
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

    private func medalCell(_ medal: MedalItem) -> some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: medal.imageURL)) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .overlay {
                            Image(systemName: "medal")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 62)

            Text(medal.name)
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(medal.isObtained ? .primary : .secondary)
        }
    }

    private func load(accountName: String?) async {
        isLoading = true
        errorMessage = ""
        snapshot = nil
        selectedTab = 0
        do {
            // The service always overrides enc_uin with the fixed value.
            let loaded = try await MedalHallService.load(urlString: urlString)
            snapshot = loaded
            if let accountName {
                queryStore.save(
                    kind: MusicQueryRecord.medalKind,
                    accountName: accountName,
                    encUin: MedalHallService.fixedEncUin,
                    summary: "分类 \(loaded.tabs.count) 个，模块 \(loaded.tabs.reduce(0) { $0 + $1.modules.count }) 个"
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadAllAccounts() async {
        isLoading = true
        errorMessage = ""
        snapshot = nil
        selectedTab = 0
        var savedCount = 0
        var lastError: String?

        for account in musicAccounts {
            do {
                let loaded = try await MedalHallService.load(urlString: urlString)
                snapshot = loaded
                savedCount += 1
                queryStore.save(
                    kind: MusicQueryRecord.medalKind,
                    accountName: account.username,
                    encUin: MedalHallService.fixedEncUin,
                    summary: "分类 \(loaded.tabs.count) 个，模块 \(loaded.tabs.reduce(0) { $0 + $1.modules.count }) 个"
                )
            } catch {
                lastError = error.localizedDescription
            }
        }

        if savedCount == 0 {
            errorMessage = lastError ?? "所有音乐账号都没有查询到勋章数据。"
        }
        isLoading = false
    }
}

private struct MedalModuleDetailView: View {
    let module: MedalModule
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(module.medals) { medal in
                        VStack(spacing: 8) {
                            AsyncImage(url: URL(string: medal.imageURL)) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit()
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(uiColor: .tertiarySystemFill))
                                        .frame(height: 84)
                                }
                            }
                            .frame(height: 84)
                            Text(medal.name)
                                .font(.caption.bold())
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            Text(medal.isObtained ? "已获得" : "未获得")
                                .font(.caption2)
                                .foregroundStyle(medal.isObtained ? .green : .secondary)
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationTitle(module.name)
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
