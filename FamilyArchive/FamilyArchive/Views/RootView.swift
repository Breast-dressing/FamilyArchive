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
        @Bindable var accessory = accessoryState

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
        .tabViewBottomAccessory(isEnabled: isAccessoryEnabled) {
            switch router.selectedTab {
            case .feed:
                if accessoryState.isFeedSearchActive {
                    SearchBottomAccessory(
                        text: $accessory.feedSearchText,
                        prompt: "搜索",
                        focus: $accessorySearchFocused,
                        onSubmit: { accessorySearchFocused = false }
                    )
                } else {
                    FeedBottomAccessory(
                        dateLabel: accessoryState.dateLabel,
                        namespace: accessoryNamespace,
                        onDateFilter: { activeSheet = .dateFilter },
                        onSearch: {
                            withAnimation(.snappy) {
                                accessoryState.isFeedSearchActive = true
                            }
                            DispatchQueue.main.async {
                                accessorySearchFocused = true
                            }
                        }
                    )
                }

            case .video:
                SearchBottomAccessory(
                    text: $accessory.videoSearchText,
                    prompt: "搜索",
                    focus: $accessorySearchFocused,
                    onSubmit: { accessorySearchFocused = false }
                )

            case .music:
                switch accessoryState.musicForm {
                case .search:
                    SearchBottomAccessory(
                        text: $accessory.musicSearchText,
                        prompt: "搜索",
                        focus: $accessorySearchFocused,
                        onSubmit: { accessorySearchFocused = false }
                    )
                case .family:
                    if accessoryState.pendingCount > 0 {
                        PendingFilesAccessoryButton(
                            count: accessoryState.pendingCount,
                            namespace: accessoryNamespace,
                            action: { activeSheet = .pendingFiles }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                    } else {
                        DateFilterAccessoryButton(
                            dateLabel: accessoryState.dateLabel,
                            namespace: accessoryNamespace,
                            action: { activeSheet = .dateFilter }
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

            case .more, .plus:
                EmptyView()
            }
        }
        .environment(router)
        .environment(pendingImports)
        .environment(dateFilterStore)
        .environment(accessoryState)
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .onChange(of: router.selectedTab) { _, newTab in
            syncAccessoryWithNavigation()
            accessorySearchFocused = false
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
        .onChange(of: router.musicPath) { _, _ in
            syncAccessoryWithNavigation()
        }
        .onChange(of: dateFilterStore.accessoryLabel) { _, newLabel in
            accessoryState.dateLabel = newLabel
            if accessoryState.musicForm == .family {
                accessoryState.updateFamily(
                    dateLabel: newLabel,
                    pendingCount: accessoryState.pendingCount
                )
            }
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

            case .feedComposer:
                FeedComposerView()

            case .videoComposer(let files):
                VideoComposerView(files: files)
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
            #endif
            accessoryState.dateLabel = dateFilterStore.accessoryLabel
            syncAccessoryWithNavigation()
            #if DEBUG
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
    /// Writes a readiness marker into the app's Documents directory. The
    /// screenshot script deletes it before launch and polls for it, which
    /// removes all fixed launch-delay races from the simulator review.
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

    /// Deterministic review routes. They drive the same router state as a real
    /// push/pop, so the accessory lifecycle is exercised without UI probing.
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
            syncAccessoryWithNavigation()
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
            || arguments.contains("-UIPreviewDateSheet")
            || arguments.contains("-UIPreviewPendingSheet") {
            showMusic([familyRoute])
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
            syncAccessoryWithNavigation()
        }

        if arguments.contains("-UIPreviewDateSheet") {
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                activeSheet = .dateFilter
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

    /// `更多` and the detached `＋` must not reserve an empty accessory bar.
    private var isAccessoryEnabled: Bool {
        switch router.selectedTab {
        case .feed, .video, .music:
            return true
        case .more, .plus:
            return false
        }
    }

    /// RootView is the single owner of the accessory lifecycle. Pushing a
    /// family value into the Music path shows the date form; popping back to
    /// the path root returns to the search field. Member pages update the
    /// same object without hiding it.
    private func syncAccessoryWithNavigation() {
        guard let route = router.musicPath.last else {
            accessoryState.leaveFamily()
            return
        }

        let familyURL = route.familyURL
        if accessoryState.familyURL != familyURL {
            accessoryState.enterFamily(
                familyURL: familyURL,
                dateLabel: dateFilterStore.accessoryLabel,
                pendingCount: pendingImports.pending(for: familyURL)?.outcome.records.count ?? 0
            )
        }
    }

    private var tabSelection: Binding<RootTab> {
        Binding(
            get: { router.selectedTab },
            set: { newValue in
                guard newValue != .plus else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    let currentTab = router.selectedTab
                    withTransaction(transaction) {
                        router.selectedTab = currentTab
                    }
                    handlePlusButtonTapped()
                    return
                }
                router.selectedTab = newValue
            }
        )
    }

    private func handlePlusButtonTapped() {
        switch router.selectedTab {
        case .music:
            if let familyURL = router.musicPath.last?.familyURL {
                filePickerPurpose = .har(familyURL: familyURL)
                isFilePickerPresented = true
            } else if router.musicSection == .archive {
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
        case .plus:
            break
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
