import SwiftUI

struct FansSkinsView: View {
    @State private var encUin = "7e-q7K4iNevP7c**"
    @State private var startSequence = 100
    @State private var endSequence = 300
    @State private var skins: [BadgeSkin] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var selectedSkin: BadgeSkin?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                inputCard

                if isLoading {
                    ProgressView("正在获取皮肤…")
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
                        description: Text("输入 enc_uin 和编号范围后获取勋章皮肤。")
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
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("勋章皮肤")
                .font(.headline)

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
                Task { await load() }
            } label: {
                Text("获取皮肤")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoading || encUin.isEmpty)
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .padding(.horizontal, 16)
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

    private func load() async {
        isLoading = true
        errorMessage = ""
        skins = []
        let lower = max(1, min(startSequence, endSequence))
        let upper = min(max(startSequence, endSequence), lower + 199)
        let sequences = Array(lower...upper)
        skins = await BadgeSkinService.fetchSkins(uin: encUin, sequences: sequences)
        if skins.isEmpty {
            errorMessage = "没有获取到皮肤，请检查 enc_uin 或编号范围。"
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
