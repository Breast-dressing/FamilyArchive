import SwiftUI
import UniformTypeIdentifiers

struct LyricCardsView: View {
    @State private var cards: [LyricCard] = []
    @State private var selectedCard: LyricCard?
    @State private var isImporterPresented = false
    @State private var isLoading = false
    @State private var errorMessage = ""

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            Group {
                if isLoading {
                    ProgressView("正在解析 HAR…")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if !errorMessage.isEmpty {
                    ContentUnavailableView(
                        "解析失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                    .padding(.vertical, 40)
                } else if cards.isEmpty {
                    ContentUnavailableView(
                        "卡牌",
                        systemImage: "rectangle.stack",
                        description: Text("导入包含歌手卡池的 HAR 文件，查看歌词卡与实体编号。")
                    )
                    .padding(.vertical, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(cards) { card in
                            Button {
                                selectedCard = card
                            } label: {
                                cardCell(card)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .navigationTitle("卡牌")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isImporterPresented = true
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("导入 HAR")
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.json, .item],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        .sheet(item: $selectedCard) { card in
            LyricCardDetailView(card: card)
        }
    }

    private func cardCell(_ card: LyricCard) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: card.imageURL)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(card.rarity)
                    .font(.caption2.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }

            Text(card.songName.isEmpty ? "未知歌曲" : card.songName)
                .font(.subheadline.bold())
                .lineLimit(1)
                .foregroundStyle(.primary)

            Text(card.singerName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            isLoading = true
            errorMessage = ""
            cards = []

            let didStart = url.startAccessingSecurityScopedResource()
            defer {
                if didStart {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                cards = try LyricCardService.parseHAR(data: data)
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}

private struct LyricCardDetailView: View {
    let card: LyricCard

    @Environment(\.dismiss) private var dismiss
    @State private var isFlipped = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Button {
                        withAnimation(.snappy) {
                            isFlipped.toggle()
                        }
                    } label: {
                        ZStack {
                            cardImage(urlString: isFlipped ? card.backImageURL : card.imageURL)
                                .opacity(isFlipped ? 0 : 1)
                            cardImage(urlString: isFlipped ? card.imageURL : card.backImageURL)
                                .opacity(isFlipped ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 320)
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottomTrailing) {
                        Label(isFlipped ? "正面" : "背面", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.thinMaterial, in: Capsule())
                            .padding(12)
                    }
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(card.songName)
                            .font(.title2.bold())
                        Text(card.singerName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Label(card.rarity, systemImage: "sparkles")
                            if card.count > 0 {
                                Label("\(card.count)", systemImage: "rectangle.stack")
                            }
                            if card.isThreeD {
                                Label("3D", systemImage: "cube")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        if !card.firstUnlockDate.isEmpty {
                            Label("首次解锁：\(card.firstUnlockDate)", systemImage: "calendar")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)

                    if !card.materials.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("卡牌材料")
                                .font(.headline)
                            ForEach(card.materials) { material in
                                HStack {
                                    Text(material.name)
                                    Spacer()
                                    Text(material.isUnlocked ? "已解锁" : "未解锁")
                                        .foregroundStyle(material.isUnlocked ? .green : .secondary)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    if !card.serials.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("实体编号")
                                .font(.headline)
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ],
                                spacing: 8
                            ) {
                                ForEach(card.serials, id: \.self) { serial in
                                    Text(serial)
                                        .font(.callout.monospacedDigit())
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            Color(uiColor: .secondarySystemBackground),
                                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        )
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationTitle("卡牌详情")
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

    private func cardImage(urlString: String) -> some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
                    .overlay {
                        Image(systemName: "rectangle.portrait")
                            .foregroundStyle(.secondary)
                    }
            }
        }
    }
}
