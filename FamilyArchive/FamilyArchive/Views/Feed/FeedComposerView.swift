import Foundation
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct FeedComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var selectedPlatform = ""
    @State private var caption = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var mediaData: [Data] = []
    @State private var mediaIsVideo: [Bool] = []
    @State private var isLoadingMedia = false
    @State private var errorMessage = ""
    @State private var showError = false

    private var scopedAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.feed.rawValue }
    }

    private var platforms: [String] {
        let unique = SocialPlatform.uniquePlatforms(from: scopedAccounts)
        return unique.isEmpty ? ["全部"] : unique
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("动态来源") {
                    if scopedAccounts.isEmpty {
                        Text("请先在“账号”中添加平台。")
                            .foregroundStyle(.secondary)
                        Text("当前将发布到“全部”来源。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("来源", selection: $selectedPlatform) {
                            ForEach(platforms, id: \.self) { platform in
                                Text(platform).tag(platform)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("照片或视频") {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 9,
                        matching: PHPickerFilter.any(of: [.images, .videos])
                    ) {
                        Label("选择照片或视频", systemImage: "photo.on.rectangle.angled")
                    }

                    if isLoadingMedia {
                        ProgressView("正在加载媒体…")
                    }

                    if !mediaData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(mediaData.indices, id: \.self) { index in
                                    mediaThumbnail(at: index)
                                }
                            }
                        }
                    }
                }

                Section("文案") {
                    TextEditor(text: $caption)
                        .frame(minHeight: 110)
                }
            }
            .navigationTitle("添加动态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { publish() }
                        .disabled(isLoadingMedia)
                }
            }
            .onAppear {
                if selectedPlatform.isEmpty {
                    selectedPlatform = platforms.first ?? "全部"
                }
            }
            .onChange(of: selectedItems) { _, items in
                Task { await loadMedia(items) }
            }
            .alert("提示", isPresented: $showError) {
                Button("好", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func mediaThumbnail(at index: Int) -> some View {
        if let image = UIImage(data: mediaData[index]) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    if index < mediaIsVideo.count, mediaIsVideo[index] {
                        Image(systemName: "play.circle.fill")
                            .foregroundStyle(.white)
                            .padding(4)
                    }
                }
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary)
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "play.rectangle.fill")
                        .foregroundStyle(.secondary)
                }
        }
    }

    @MainActor
    private func loadMedia(_ items: [PhotosPickerItem]) async {
        isLoadingMedia = true
        defer { isLoadingMedia = false }

        var loadedData: [Data] = []
        var loadedIsVideo: [Bool] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loadedData.append(data)
                loadedIsVideo.append(item.supportedContentTypes.contains { $0.conforms(to: .movie) })
            }
        }
        mediaData = loadedData
        mediaIsVideo = loadedIsVideo
    }

    private func publish() {
        let trimmedCaption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !mediaData.isEmpty else {
            errorMessage = "请选择至少一张照片或视频。"
            showError = true
            return
        }
        guard !selectedPlatform.isEmpty else {
            errorMessage = "请选择动态来源。"
            showError = true
            return
        }
        if !scopedAccounts.isEmpty, selectedPlatform == "全部" {
            errorMessage = "请选择具体的动态来源。"
            showError = true
            return
        }

        let post = FeedPost(
            platform: selectedPlatform,
            caption: trimmedCaption,
            mediaData: mediaData,
            mediaIsVideo: mediaIsVideo
        )
        modelContext.insert(post)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "保存失败：\(error.localizedDescription)"
            showError = true
        }
    }
}
