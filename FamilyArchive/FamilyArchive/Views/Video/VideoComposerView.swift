import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct VideoComposerView: View {
    let files: [URL]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var selectedPlatform = ""
    @State private var title = ""
    @State private var synopsis = ""
    @State private var cast = ""
    @State private var coverItem: PhotosPickerItem?
    @State private var coverData: Data?
    @State private var episodeTitles: [String]
    @State private var errorMessage = ""
    @State private var showError = false

    init(files: [URL]) {
        self.files = files
        _episodeTitles = State(initialValue: files.map { $0.deletingPathExtension().lastPathComponent })
    }

    private var scopedAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.video.rawValue }
    }

    private var platforms: [String] {
        let unique = SocialPlatform.uniquePlatforms(from: scopedAccounts)
        return unique.isEmpty ? ["全部"] : unique
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("封面") {
                    PhotosPicker(selection: $coverItem, matching: .images) {
                        Label("选择封面", systemImage: "photo")
                    }
                    if let coverData, let image = UIImage(data: coverData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Section("名字") {
                    TextField("名字", text: $title)
                }

                Section("简介&演职员表") {
                    TextField("简介", text: $synopsis, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("演职员表", text: $cast, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("剧集") {
                    if files.isEmpty {
                        Text("没有可添加的剧集文件。")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(files.indices, id: \.self) { index in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(files[index].lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("剧集标题", text: $episodeTitles[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("添加影视")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("影视来源", selection: $selectedPlatform) {
                        ForEach(platforms, id: \.self) { platform in
                            Text(platform).tag(platform)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
            .onAppear {
                if selectedPlatform.isEmpty {
                    selectedPlatform = platforms.first ?? "全部"
                }
            }
            .onChange(of: coverItem) { _, item in
                guard let item else {
                    coverData = nil
                    return
                }
                Task { @MainActor in
                    coverData = try? await item.loadTransferable(type: Data.self)
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSynopsis = synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCast = cast.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEpisodes = episodeTitles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        guard !trimmedTitle.isEmpty else {
            fail("请输入名字。")
            return
        }
        guard coverData != nil else {
            fail("请选择封面。")
            return
        }
        guard !trimmedSynopsis.isEmpty else {
            fail("请输入简介。")
            return
        }
        guard !trimmedCast.isEmpty else {
            fail("请输入演职员表。")
            return
        }
        guard !files.isEmpty, trimmedEpisodes.allSatisfy({ !$0.isEmpty }) else {
            fail("请为每个剧集填写标题。")
            return
        }
        guard !selectedPlatform.isEmpty else {
            fail("请选择影视来源。")
            return
        }

        let show = VideoShow(
            platform: selectedPlatform,
            title: trimmedTitle,
            synopsis: trimmedSynopsis,
            cast: trimmedCast,
            coverData: coverData,
            episodeTitles: trimmedEpisodes,
            episodeFileNames: files.map(\.lastPathComponent)
        )
        modelContext.insert(show)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            fail("保存失败：\(error.localizedDescription)")
        }
    }

    private func fail(_ message: String) {
        errorMessage = message
        showError = true
    }
}
