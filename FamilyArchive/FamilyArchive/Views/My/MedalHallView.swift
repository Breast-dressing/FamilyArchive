import SwiftUI

struct MedalHallView: View {
    @State private var urlString =
        "https://i2.y.qq.com/n3/client/pages/medal_collection_new/index.html?_hidehd=1&_fontscale=1&_miniplayer=1&enc_uin=oKEkoiCFoKCAoz**&entry=profile&_button=1"
    @State private var snapshot: MedalHallSnapshot?
    @State private var selectedTab = 0
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var selectedModule: MedalModule?

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
                Task { await load() }
            } label: {
                Text("开始解析")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || urlString.isEmpty)
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

    private func load() async {
        isLoading = true
        errorMessage = ""
        snapshot = nil
        selectedTab = 0
        do {
            snapshot = try await MedalHallService.load(urlString: urlString)
        } catch {
            errorMessage = error.localizedDescription
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
