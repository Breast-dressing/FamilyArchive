//
//  RootView.swift
//  FamilyArchive
//
//  The native bottom tab bar. The "＋" item is a real tab item declared with
//  `role: .prominent`, which the system places in a separate trailing position
//  of the tab bar (the detached tab item on iOS 27). Its selection is
//  intercepted, so tapping it never switches tabs and never shows a page: it
//  only presents an option list that depends on the current page.
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

    @State private var importTargetFamilyURL: String?
    @State private var isImporterPresented = false
    @State private var isImportingHAR = false
    @State private var message: AppMessage?

    var body: some View {
        TabView(selection: tabSelection) {
            Tab("Feed", systemImage: "square.stack", value: RootTab.feed) {
                FeedView()
            }

            Tab("Video", systemImage: "play.rectangle", value: RootTab.video) {
                VideoView()
            }

            Tab("Music", systemImage: "music.note", value: RootTab.music) {
                MusicRootView()
            }

            Tab("More", systemImage: "ellipsis", value: RootTab.more) {
                MoreView()
            }

            // Detached tab item: never selected, never a page.
            Tab("＋", systemImage: "plus", value: RootTab.plus, role: .prominent) {
                EmptyView()
            }
        }
        .environment(router)
        .onChange(of: router.selectedTab) { previousTab, newTab in
            // Defensive fallback: if the platform ever applies the detached
            // tab's selection without going through the interception above,
            // put the selection back and open the options anyway.
            guard newTab == .plus else { return }
            router.selectedTab = previousTab
            handlePlusButtonTapped()
        }
        .sheet(item: $router.plusRoute) { route in
            PlusActionsSheet(route: route) { action in
                handleArchiveAction(action)
            }
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: Self.harPickerTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .alert(messageTitle, isPresented: messageIsPresented) {
            Button("OK", role: .cancel) {
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

    /// Tapping "＋" writes `.plus` into this binding. The setter intercepts that
    /// value, presents the page-specific options instead, and leaves
    /// `selectedTab` untouched, so no tab switch ever happens.
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
                // Family detail page: "＋" picks HAR files for this family.
                importTargetFamilyURL = familyURL
                isImporterPresented = true
            } else if router.musicSection == .archive {
                // Music -> Archive: the four archive actions.
                router.plusRoute = .archiveActions
            } else {
                router.plusRoute = .unavailable(pageName: "Music")
            }
        case .feed:
            router.plusRoute = .unavailable(pageName: "Feed")
        case .video:
            router.plusRoute = .unavailable(pageName: "Video")
        case .more:
            router.plusRoute = .unavailable(pageName: "More")
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
        // Let the option sheet finish dismissing before the system paste prompt
        // (or an error alert) is presented.
        try? await Task.sleep(for: .milliseconds(250))

        guard let clipboardText = UIPasteboard.general.string,
              !clipboardText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = AppMessage(
                title: "Family",
                message: "The clipboard is empty. Copy a family link first."
            )
            return
        }

        guard let familyURL = FamilyURLParser.detectURL(in: clipboardText) else {
            message = AppMessage(
                title: "Family",
                message: "No URL was found in the clipboard content."
            )
            return
        }

        // Phase 1: the pure part of the reference URL parsing (query parameters
        // / path). It makes the family appear in the section immediately, even
        // if the network requests below are slow or unavailable.
        let knownFamilyID = FamilyURLParser.extractFamilyID(from: familyURL) ?? ""
        let quickName: String
        if !knownFamilyID.isEmpty {
            quickName = "Family \(knownFamilyID)"
        } else if let host = familyURL.host, !host.isEmpty {
            quickName = host
        } else {
            quickName = "Family"
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
                title: "Family",
                message: "The family could not be saved: \(saveError)"
            )
            return
        }

        // Phase 2: the rest of `fetch_family_from_url` — short-link resolution,
        // SSR family info, and the member APIs. The stored family is updated
        // in place because the URL is the family identity.
        let parsed = await FamilyService.loadFamily(from: familyURL)
        if let saveError = saveFamily(parsed) {
            message = AppMessage(
                title: "Family",
                message: "The family could not be saved: \(saveError)"
            )
        }
    }

    @MainActor
    private func saveFamily(_ parsed: ParsedFamily) -> String? {
        let urlString = parsed.url
        guard !urlString.isEmpty else {
            return "The family URL is empty."
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
                name: parsed.name.isEmpty ? "Family" : parsed.name,
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

    // MARK: - HAR import

    private static var harPickerTypes: [UTType] {
        let harType = UTType(filenameExtension: "har", conformingTo: .json) ?? .json
        if harType.identifier == UTType.json.identifier {
            return [.json]
        }
        return [harType, .json]
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            message = AppMessage(title: "HAR Import", message: error.localizedDescription)

        case .success(let urls):
            guard !urls.isEmpty else { return }
            guard let familyURL = importTargetFamilyURL else {
                message = AppMessage(
                    title: "HAR Import",
                    message: "Open a family before importing HAR files."
                )
                return
            }
            importTargetFamilyURL = nil

            // Keep the security-scoped access alive while the files are read off
            // the main thread.
            let scopedURLs: [(url: URL, didStartAccessing: Bool)] = urls.map { url in
                (url: url, didStartAccessing: url.startAccessingSecurityScopedResource())
            }

            isImportingHAR = true
            Task {
                let outcome = await HARImportService.parse(urls: scopedURLs.map { $0.url })
                for item in scopedURLs where item.didStartAccessing {
                    item.url.stopAccessingSecurityScopedResource()
                }
                applyImport(outcome, familyURL: familyURL)
                isImportingHAR = false
            }
        }
    }

    @MainActor
    private func applyImport(_ outcome: HARImportOutcome, familyURL: String) {
        let storedMembers = (try? modelContext.fetch(FetchDescriptor<FamilyMember>())) ?? []
        let familyMembers = storedMembers.filter { $0.familyURL == familyURL }

        var importedCount = 0
        var notFoundCount = 0
        var ambiguousCount = 0
        var notFoundNames: [String] = []
        var ambiguousNames: [String] = []

        for record in outcome.records {
            switch MemberNameResolver.resolve(record.memberName, in: familyMembers) {
            case .resolved(let memberID):
                let honorRecord = HonorRecord(
                    memberID: memberID,
                    taskName: record.taskName,
                    honorValue: record.honorValue,
                    time: record.time,
                    familyURL: familyURL
                )
                modelContext.insert(honorRecord)
                importedCount += 1

            case .notFound:
                notFoundCount += 1
                appendUniqueName(record.memberName, to: &notFoundNames)

            case .ambiguous:
                ambiguousCount += 1
                appendUniqueName(record.memberName, to: &ambiguousNames)
            }
        }

        var saveError: String?
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }

        var lines: [String] = [
            "Imported \(importedCount) record\(importedCount == 1 ? "" : "s")."
        ]
        if notFoundCount > 0 {
            lines.append(
                "Skipped \(notFoundCount) record\(notFoundCount == 1 ? "" : "s") for members that were not found: \(notFoundNames.joined(separator: ", "))."
            )
        }
        if ambiguousCount > 0 {
            lines.append(
                "Skipped \(ambiguousCount) record\(ambiguousCount == 1 ? "" : "s") with ambiguous member names: \(ambiguousNames.joined(separator: ", "))."
            )
        }
        if importedCount == 0 {
            lines.append(
                "Files: \(outcome.fileCount), matching responses: \(outcome.matchedResponseCount), kept after deduplication: \(outcome.keptResponseCount)."
            )
        }
        lines.append(contentsOf: outcome.warnings)
        if let saveError {
            lines.append("Saving failed: \(saveError)")
        }

        message = AppMessage(title: "HAR Import", message: lines.joined(separator: "\n\n"))
    }

    private func appendUniqueName(_ name: String, to names: inout [String]) {
        guard names.count < 6, !names.contains(name) else { return }
        names.append(name)
    }

    // MARK: - Alert / progress

    private var messageTitle: String {
        message?.title ?? "Notice"
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
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                Text("Importing HAR files…")
                    .font(.footnote)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
