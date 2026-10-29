//
//  RootView.swift
//  FamilyArchive
//
//  Native bottom tab bar. 更多 is declared with `role: .prominent`, which the
//  system detaches from the main tab group and places in a separate trailing
//  position, while still selecting its page normally.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// One sheet source for the whole root. Multiple `.sheet` modifiers on the
/// same TabView can swallow each other, especially from the bottom accessory.
enum RootSheet: Identifiable {
    case dateFilter
    case pendingFiles
    case plus(PlusRoute)
    case feedComposer
    case videoComposer([URL])

    var id: String {
        switch self {
        case .dateFilter:
            return "dateFilter"
        case .pendingFiles:
            return "pendingFiles"
        case .plus(let route):
            return "plus-\(route.id)"
        case .feedComposer:
            return "feedComposer"
        case .videoComposer:
            return "videoComposer"
        }
    }
}

struct AppMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var router = AppRouter()
    @State private var pendingImports = PendingImportStore()
    @State private var dateFilterStore = DateFilterStore()
    @State private var accessoryState = RootAccessoryState()
    @Namespace private var accessoryNamespace

    @State private var filePickerPurpose: FilePickerPurpose?
    @State private var isFilePickerPresented = false
    @State private var isImportingHAR = false
    @State private var message: AppMessage?

    @State private var activeSheet: RootSheet?
    @FocusState private var accessorySearchFocused: Bool

    private enum FilePickerPurpose {
        case har(familyURL: String)
        case video
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab(RootTab.feed.title, systemImage: RootTab.feed.systemImage, value: RootTab.feed) {
                FeedView()
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        bottomBarInset
                    }
            }

            Tab(RootTab.video.title, systemImage: RootTab.video.systemImage, value: RootTab.video) {
                VideoView()
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        bottomBarInset
                    }
            }

            Tab(RootTab.music.title, systemImage: RootTab.music.systemImage, value: RootTab.music) {
                MusicRootView()
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        bottomBarInset
                    }
            }

            Tab(RootTab.more.title, systemImage: RootTab.more.systemImage, value: RootTab.more, role: .prominent) {
                MoreView()
            }
        }
        .tint(.blue)
        .environment(router)
        .environment(pendingImports)
        .environment(dateFilterStore)
        .environment(accessoryState)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .onChange(of: router.selectedTab) { _, newTab in
            accessorySearchFocused = false
            router.isFeedDetailActive = false
            if newTab != .feed {
                accessoryState.isFeedSearchActive = false
                accessoryState.feedSearchText = ""
            }
        }
        .onChange(of: accessorySearchFocused) { _, isFocused in
            guard !isFocused, accessoryState.isFeedSearchActive else { return }
            withAnimation(.snappy) {
                accessoryState.isFeedSearchActive = false
            }
            accessoryState.feedSearchText = ""
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .dateFilter:
                DateFilterPopover()
                    .environment(dateFilterStore)
                    .presentationDetents([.height(380)])
                    .navigationTransition(
                        .zoom(
                            sourceID: AccessoryTransition.dateFilter,
                            in: accessoryNamespace
                        )
                    )

            case .pendingFiles:
                if let familyURL = accessoryState.familyURL {
                    PendingFilesView(
                        familyURL: familyURL,
                        memberName: accessoryState.memberName
                    )
                    .environment(pendingImports)
                    .presentationDetents([.medium, .large])
                    .navigationTransition(
                        .zoom(
                            sourceID: AccessoryTransition.pendingFiles,
                            in: accessoryNamespace
                        )
                    )
                }

            case .plus(let route):
                PlusActionsSheet(route: route) { action in
                    handleArchiveAction(action)
                }
                .navigationTransition(
                    .zoom(
                        sourceID: AccessoryTransition.plus,
                        in: accessoryNamespace
                    )
                )

            case .feedComposer:
                FeedComposerView()
                    .navigationTransition(
                        .zoom(
                            sourceID: AccessoryTransition.plus,
                            in: accessoryNamespace
                        )
                    )

            case .videoComposer(let files):
                VideoComposerView(files: files)
                    .navigationTransition(
                        .zoom(
                            sourceID: AccessoryTransition.plus,
                            in: accessoryNamespace
                        )
                    )
            }
        }
        .fileImporter(
            isPresented: $isFilePickerPresented,
            allowedContentTypes: [.item],
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
        .onAppear {
            #if DEBUG
            UIPreviewSeed.seedIfNeeded(in: modelContext)
            applyUIPreviewRoute()
            writePreviewReadyFile()
            #endif
        }
        .overlay {
            if isImportingHAR {
                workingOverlay
            }
        }
    }

    #if DEBUG
    private func writePreviewReadyFile() {
        guard ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-UIPreview") }) else {
            return
        }
        guard let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return
        }
        let marker = documents.appendingPathComponent("UIPreviewReady")
        try? Data("ready".utf8).write(to: marker)
    }

    private func applyUIPreviewRoute() {
        let arguments = Set(ProcessInfo.processInfo.arguments)
        let previewArguments = arguments.filter { $0.hasPrefix("-UIPreview") }
        guard !previewArguments.isEmpty,
              let family = (try? modelContext.fetch(FetchDescriptor<Family>()))?
                  .first(where: { $0.name == "jaychou" }) else {
            return
        }

        let familyRoute = MusicRoute.family(family.url)
        let memberRoute = MusicRoute.member(
            familyURL: family.url,
            memberID: "preview-member-0"
        )

        func showMusic(_ path: [MusicRoute]) {
            router.selectedTab = .music
            router.musicSection = .archive
            router.musicPath = path
        }

        if arguments.contains("-UIPreviewPending")
            || arguments.contains("-UIPreviewPendingSheet") {
            pendingImports.setPending(
                UIPreviewSeed.pendingOutcome(),
                for: family.url
            )
        }

        if arguments.contains("-UIPreviewTour") {
            showMusic([familyRoute, memberRoute])
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                guard router.musicPath.count == 2 else { return }
                router.musicPath = [familyRoute]

                try? await Task.sleep(for: .seconds(5))
                guard router.musicPath.count == 1 else { return }
                router.musicPath = []
            }
        } else if arguments.contains("-UIPreviewMember") {
            showMusic([familyRoute, memberRoute])
        } else if arguments.contains("-UIPreviewFamily")
            || arguments.contains("-UIPreviewPendingSheet") {
            showMusic([familyRoute])
        } else if arguments.contains("-UIPreviewFans") {
            showMusic([.fans])
        } else if arguments.contains("-UIPreviewMedals") {
            showMusic([.medals])
        } else if arguments.contains("-UIPreviewCards") {
            showMusic([.cards])
        } else if arguments.contains("-UIPreviewDateSheet") {
            showMusic([])
        } else if arguments.contains("-UIPreviewFeedSearch") {
            router.selectedTab = .feed
            accessoryState.isFeedSearchActive = true
        } else if arguments.contains("-UIPreviewSearchFocus") {
            router.selectedTab = .feed
            accessoryState.isFeedSearchActive = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                accessorySearchFocused = true
            }
        } else if arguments.contains("-UIPreviewMusic") {
            showMusic([])
        } else if arguments.contains("-UIPreviewFeed") {
            router.selectedTab = .feed
        } else if arguments.contains("-UIPreviewVideo") {
            router.selectedTab = .video
        } else if arguments.contains("-UIPreviewMore") {
            router.selectedTab = .more
        } else if arguments.contains("-UIPreviewArchive") {
            router.selectedTab = .music
            router.musicSection = .archive
        }

        if arguments.contains("-UIPreviewDateSheet") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                activeSheet = .dateFilter
            }
        }

        if arguments.contains("-UIPreviewFeedPlus") {
            router.selectedTab = .feed
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                activeSheet = .feedComposer
            }
        }

        if arguments.contains("-UIPreviewMusicPlus") {
            showMusic([])
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                activeSheet = .plus(.archiveActions)
            }
        }

        if arguments.contains("-UIPreviewPendingSheet") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                activeSheet = .pendingFiles
            }
        }
    }
    #endif

    // MARK: - Tab selection

    private var currentSearchText: Binding<String> {
        Binding(
            get: {
                switch router.selectedTab {
                case .feed:
                    return accessoryState.feedSearchText
                case .video:
                    return accessoryState.videoSearchText
                case .music:
                    return accessoryState.musicSearchText
                default:
                    return ""
                }
            },
            set: { value in
                switch router.selectedTab {
                case .feed:
                    accessoryState.feedSearchText = value
                case .video:
                    accessoryState.videoSearchText = value
                case .music:
                    accessoryState.musicSearchText = value
                default:
                    break
                }
            }
        )
    }

    @ViewBuilder
    private var bottomBar: some View {
        BottomToolbar(
            tab: router.selectedTab,
            dateLabel: dateFilterStore.accessoryLabel,
            namespace: accessoryNamespace,
            searchText: currentSearchText,
            focus: $accessorySearchFocused,
            onSearchSubmit: {
                accessorySearchFocused = false
            },
            onDateTap: {
                activeSheet = .dateFilter
            },
            onPlusTap: {
                handlePlusButtonTapped()
            }
        )
    }

    /// The floating bar shares the tab bar's downward exit: both slide off the
    /// bottom edge together, then the system removes the tab bar. Returning
    /// plays the same move in reverse.
    @ViewBuilder
    private var bottomBarInset: some View {
        ZStack(alignment: .bottom) {
            if !isBottomBarHidden {
                bottomBar
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isBottomBarHidden)
    }

    /// 二级页面只隐藏系统 TabBar，悬浮工具栏保持显示。
    private var isBottomBarHidden: Bool {
        router.selectedTab == .more
    }

    private func handlePlusButtonTapped() {
        switch router.selectedTab {
        case .music:
            if router.musicSection == .archive {
                activeSheet = .plus(.archiveActions)
            } else {
                activeSheet = .plus(.unavailable(pageName: "音乐"))
            }
        case .feed:
            activeSheet = .feedComposer
        case .video:
            filePickerPurpose = .video
            isFilePickerPresented = true
        case .more:
            activeSheet = .plus(.unavailable(pageName: "更多"))
        }
    }

    // MARK: - Archive actions

    private func handleArchiveAction(_ action: ArchiveAction) {
        activeSheet = nil
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
            signature: "",
            honor: "",
            weekRank: "",
            memberCountText: "",
            pkWins: "",
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
            if !parsed.avatarURL.isEmpty, parsed.avatarURL != existing.avatarURL {
                recordAvatarHistory(familyURL: urlString, avatarURL: parsed.avatarURL)
                existing.avatarURL = parsed.avatarURL
            }
            if !parsed.signature.isEmpty { existing.signature = parsed.signature }
            if !parsed.honor.isEmpty { existing.honor = parsed.honor }
            if !parsed.weekRank.isEmpty { existing.weekRank = parsed.weekRank }
            if !parsed.memberCountText.isEmpty { existing.memberCountText = parsed.memberCountText }
            if !parsed.pkWins.isEmpty { existing.pkWins = parsed.pkWins }
        } else {
            let nextSortOrder = (storedFamilies.map(\.sortOrder).max() ?? 0) + 1
            let family = Family(
                url: urlString,
                name: parsed.name.isEmpty ? "家族" : parsed.name,
                familyID: parsed.familyID,
                avatarURL: parsed.avatarURL,
                signature: parsed.signature,
                honor: parsed.honor,
                weekRank: parsed.weekRank,
                memberCountText: parsed.memberCountText,
                pkWins: parsed.pkWins,
                sortOrder: nextSortOrder
            )
            modelContext.insert(family)
            if !parsed.avatarURL.isEmpty {
                recordAvatarHistory(familyURL: urlString, avatarURL: parsed.avatarURL)
            }
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
                if !payload.medalLevel.isEmpty { existingMember.medalLevel = payload.medalLevel }
                if !payload.nameplate.isEmpty { existingMember.nameplate = payload.nameplate }
                if payload.apiHonor > 0 { existingMember.apiHonor = payload.apiHonor }
            } else {
                let member = FamilyMember(
                    memberID: payload.memberID,
                    name: payload.name,
                    avatarURL: payload.avatarURL,
                    familyURL: urlString,
                    medalLevel: payload.medalLevel,
                    nameplate: payload.nameplate,
                    apiHonor: payload.apiHonor
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

    /// Keep a time-stamped avatar history whenever the resolved URL changes.
    private func recordAvatarHistory(familyURL: String, avatarURL: String) {
        guard !avatarURL.isEmpty else { return }
        let histories = (try? modelContext.fetch(FetchDescriptor<FamilyAvatarHistory>())) ?? []
        for history in histories
        where history.familyURL == familyURL && history.endDate == nil {
            history.endDate = .now
        }
        modelContext.insert(
            FamilyAvatarHistory(
                familyURL: familyURL,
                avatarURL: avatarURL,
                startDate: .now,
                endDate: nil
            )
        )
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
                // Start security-scoped access inside the fileImporter
                // completion handler; keep it alive until the detached HAR
                // parse finishes, then stop every scope.
                let scopedURLs: [(url: URL, didStartAccessing: Bool)] = urls.map { url in
                    (url: url, didStartAccessing: url.startAccessingSecurityScopedResource())
                }
                isImportingHAR = true
                Task { @MainActor in
                    defer {
                        for item in scopedURLs where item.didStartAccessing {
                            item.url.stopAccessingSecurityScopedResource()
                        }
                    }
                    let outcome = await HARImportService.parse(urls: scopedURLs.map { $0.url })
                    pendingImports.setPending(outcome, for: familyURL)
                    isImportingHAR = false
                }
            case .video:
                prepareVideoComposer(urls)
            }
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
        let files = selection.accepted
        Task { @MainActor in
            // Let the file importer finish dismissing before presenting the sheet.
            try? await Task.sleep(for: .milliseconds(250))
            activeSheet = .videoComposer(files)
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
