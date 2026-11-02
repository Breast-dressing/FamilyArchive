import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// 添加音乐：从本地导入音频文件，填分类，可归入某个自建歌单。
struct MusicComposerView: View {
    private struct ImportedAudio: Identifiable {
        let id = UUID()
        let fileName: String
        var title: String
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]

    @State private var isPickerPresented = false
    @State private var imported: [ImportedAudio] = []
    @State private var selectedCategory = SongCategory.solo.rawValue
    @State private var selectedPlaylistID: UUID?
    @State private var errorMessage = ""
    @State private var showError = false

    private let store = AudioFileStore()

    var body: some View {
        NavigationStack {
            Form {
                Section("音频文件") {
                    Button {
                        isPickerPresented = true
                    } label: {
                        Label("导入本地音频", systemImage: "square.and.arrow.down")
                    }

                    if imported.isEmpty {
                        Text("支持 m4a / mp3 / wav 等本地音频。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach($imported) { $item in
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("歌曲名", text: $item.title)
                            Text(item.fileName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("分类") {
                    Picker("分类", selection: $selectedCategory) {
                        ForEach(SongCategory.allCases) { category in
                            Text(category.title).tag(category.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if !playlists.isEmpty {
                    Section("加入歌单") {
                        Picker("歌单", selection: $selectedPlaylistID) {
                            Text("不加入").tag(UUID?.none)
                            ForEach(playlists) { playlist in
                                Text(playlist.name).tag(UUID?.some(playlist.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加音乐")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(imported.isEmpty)
                }
            }
            .fileImporter(
                isPresented: $isPickerPresented,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .alert("提示", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.large])
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            do {
                for url in urls {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer {
                        if scoped { url.stopAccessingSecurityScopedResource() }
                    }
                    let fileName = try store.importAudio(from: url)
                    imported.append(
                        ImportedAudio(
                            fileName: fileName,
                            title: url.deletingPathExtension().lastPathComponent
                        )
                    )
                }
            } catch {
                errorMessage = "导入失败：\(error.localizedDescription)"
                showError = true
            }
        case .failure(let error):
            errorMessage = "读取文件失败：\(error.localizedDescription)"
            showError = true
        }
    }

    private func save() {
        var order = 0
        for item in imported {
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            let song = Song(
                title: title,
                category: selectedCategory,
                fileName: item.fileName,
                playlistID: selectedPlaylistID,
                sortOrder: order
            )
            modelContext.insert(song)
            order += 1
        }
        guard order > 0 else {
            errorMessage = "请至少填写一首歌名。"
            showError = true
            return
        }
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            showError = true
        }
    }
}
