//
//  RootView.swift
//  FamilyArchive
//
//  Native bottom tab bar. The "＋" item is a real tab item declared with
//  `role: .prominent`, which the system places in a separate trailing position
//  of the tab bar. Its selection is intercepted, so tapping it never switches
//  tabs: it presents the action that belongs to the current page.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AppMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = AppRouter()
    @State private var pendingImports = PendingImportStore()

    @State private var filePickerPurpose: FilePickerPurpose?
    @State private var isFilePickerPresented = false
    @State private var isImportingHAR = false
    @State private var message: AppMessage?

    @State private var isFeedComposerPresented = false
    @State private var isVideoComposerPresented = false
    @State private var videoComposerFiles: [URL] = []

    private enum FilePickerPurpose {
        case har(familyURL: String)
        case video
    }

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("动态", systemImage: "square.stack", value: RootTab.feed) {
                FeedView()
            }

            Tab("影视", systemImage: "play.rectangle", value: RootTab.video) {
                VideoView()
            }

            Tab("音乐", systemImage: "music.note", value: RootTab.music) {
                MusicRootView()
            }

            Tab("更多", systemImage: "ellipsis", value: RootTab.more) {
                MoreView()
            }

            // Detached tab item: never selected, never a page.
            Tab("＋", systemImage: "plus", value: RootTab.plus, role: .prominent) {
                EmptyView()
            }
        }
        .tint(.blue)
        .environment(router)
        .environment(pendingImports)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .onChange(of: router.selectedTab) { previousTab, newTab in
            guard newTab == .plus else { return }
            router.selectedTab = previousTab
            handlePlusButtonTapped()
        }
        .sheet(item: $router.plusRoute) { route in
            PlusActionsSheet(route: route) { action in
                handleArchiveAction(action)
            }
        }
        .sheet(isPresented: $isFeedComposerPresented) {
            FeedComposerView()
        }
        .sheet(isPresented: $isVideoComposerPresented) {
            VideoComposerView(files: videoComposerFiles)
        }
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.data],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .alert(messageTitle, isPresented: messageIsPresented) {
            Button("好", role: .cancel) {
                message = nil
            }
        } message: {
            Text(message?.message ?? "")
        }
        .overlay {
            if isImportingHAR {
                workingOverlay
            }
        }
    }

    // MARK: - Tab selection

    private var tabSelection: Binding<RootTab> {
        Binding(
            get: { router.selectedTab },
            set: { newValue in
                if newValue == .plus {
                    Task { @MainActor in
                        handlePlusButtonTapped()
                    }
                } else {
                    router.selectedTab = newValue
                }
            }
        )
    }

    private func handlePlusButtonTapped() {
        switch router.selectedTab {
        case .music:
            if let familyURL = router.musicPath.last {
                filePickerPurpose = .har(familyURL: familyURL)
                isFilePickerPresented = true
            } else if router.musicSection == .archive {
                router.plusRoute = .archiveActions
            } else {
                router.plusRoute = .unavailable(pageName: "音乐")
            }
        case .feed:
            isFeedComposerPresented = true
        case .video:
            filePickerPurpose = .video
            isFilePickerPresented = true
        case .more:
            router.plusRoute = .unavailable(pageName: "更多")
        case .plus:
            break
        }
    }

    // MARK: - Archive actions

    private func handleArchiveAction(_ action: ArchiveAction) {
        router.plusRoute = nil
        guard action == .family else { return }
        Task { @MainActor in
            await addFamilyFromClipboard()
        }
    }

    @MainActor
    private func addFamilyFromClipboard() async {
        try? await Task.sleep(for: .milliseconds(250))

        guard let clipboardText = UIPasteboard.general.string,
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = AppMessage(
                title: "家族",
                message: "剪贴板为空，请先复制家族链接。"
            )
            return
        }

        guard let familyURL = FamilyURLParser.detectURL(in: clipboardText) else {
            message = AppMessage(
                title: "家族",
                message: "剪贴板中没有找到链接。"
            )
            return
        }

        let knownFamilyID = FamilyURLParser.extractFamilyID(from: familyURL) ?? ""
        let quickName: String
        if !knownFamilyID.isEmpty {
            quickName = "家族 \(knownFamilyID)"
        } else if let host = familyURL.host, !host.isEmpty {
            quickName = host
        } else {
            quickName = "家族"
        }
        let quickFamily = ParsedFamily(
            url: familyURL.absoluteString,
            familyID: knownFamilyID,
            name: quickName,
            nameIsResolved: false,
            avatarURL: "",
            members: []
        )
        if let saveError = saveFamily(quickFamily) {
            message = AppMessage(
                title: "家族",
                message: "家族保存失败：\(saveError)"
            )
            return
        }

        let parsed = await FamilyService.loadFamily(from: familyURL)
        if let saveError = saveFamily(parsed) {
            message = AppMessage(
                title: "家族",
                message: "家族保存失败：\(saveError)"
            )
        }
    }

    @MainActor
    private func saveFamily(_ parsed: ParsedFamily) -> String? {
        let urlString = parsed.url
        guard !urlString.isEmpty else {
            return "家族链接为空。"
        }

        let storedFamilies = (try? modelContext.fetch(FetchDescriptor<Family>())) ?? []
        if let existing = storedFamilies.first(where: { $0.url == urlString }) {
            if parsed.nameIsResolved {
                existing.name = parsed.name
            }
            if !parsed.familyID.isEmpty {
                existing.familyID = parsed.familyID
            }
            if !parsed.avatarURL.isEmpty {
                existing.avatarURL = parsed.avatarURL
            }
        } else {
            let family = Family(
                url: urlString,
                name: parsed.name.isEmpty ? "家族" : parsed.name,
                familyID: parsed.familyID,
                avatarURL: parsed.avatarURL
            )
            modelContext.insert(family)
        }

        let storedMembers = (try? modelContext.fetch(FetchDescriptor<FamilyMember>())) ?? []
        var membersByID: [String: FamilyMember] = [:]
        for member in storedMembers {
            membersByID[member.memberID] = member
        }

        for payload in parsed.members where !payload.memberID.isEmpty {
            if let existingMember = membersByID[payload.memberID] {
                existingMember.name = payload.name
                existingMember.avatarURL = payload.avatarURL
                existingMember.familyURL = urlString
            } else {
                let member = FamilyMember(
                    memberID: payload.memberID,
                    name: payload.name,
                    avatarURL: payload.avatarURL,
                    familyURL: urlString
                )
                modelContext.insert(member)
                membersByID[payload.memberID] = member
            }
        }

        do {
            try modelContext.save()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - File selection

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            filePickerPurpose = nil
            message = AppMessage(title: "文件选择失败", message: error.localizedDescription)

        case .success(let urls):
            guard let purpose = filePickerPurpose, !urls.isEmpty else {
                filePickerPurpose = nil
                return
            }
            filePickerPurpose = nil

            switch purpose {
            case .har(let familyURL):
                importHAR(urls, familyURL: familyURL)
            case .video:
                prepareVideoComposer(urls)
            }
        }
    }

    private func importHAR(_ urls: [URL], familyURL: String) {
        let scopedURLs: [(url: URL, didStartAccessing: Bool)] = urls.map { url in
            (url: url, didStartAccessing: url.startAccessingSecurityScopedResource())
        }

        isImportingHAR = true
        Task { @MainActor in
            let outcome = await HARImportService.parse(urls: scopedURLs.map { $0.url })
            for item in scopedURLs where item.didStartAccessing {
                item.url.stopAccessingSecurityScopedResource()
            }
            pendingImports.setPending(outcome, for: familyURL)
            isImportingHAR = false
        }
    }

    private func prepareVideoComposer(_ urls: [URL]) {
        let selection = FileSelectionValidator.partition(urls)
        guard selection.rejected.isEmpty else {
            let names = selection.rejected.map(\.lastPathComponent).joined(separator: "、")
            message = AppMessage(
                title: "文件类型不支持",
                message: "照片和视频请使用照片选择器选择。已取消本次文件选择：\(names)"
            )
            return
        }

        guard !selection.accepted.isEmpty else { return }
        videoComposerFiles = selection.accepted
        Task { @MainActor in
            // Let the file importer finish dismissing before presenting the sheet.
            try? await Task.sleep(for: .milliseconds(250))
            isVideoComposerPresented = true
        }
    }

    // MARK: - Alert / progress

    private var messageTitle: String {
        message?.title ?? "提示"
    }

    private var messageIsPresented: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { isPresented in
                if !isPresented {
                    message = nil
                }
            }
        )
    }

    private var workingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("正在解析文件…")
                    .font(.footnote)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
