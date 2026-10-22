//
//  FamilyArchiveApp.swift
//  FamilyArchive
//
//  iOS 27 / SwiftUI app entry point.
//

import SwiftData
import SwiftUI

@main
struct FamilyArchiveApp: App {
    /// The schema is built explicitly so every stored model is part of the
    /// container. (`ModelContainer(for:...)` is the variadic initializer of
    /// SwiftData's model container.)
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(
                for: Family.self,
                FamilyMember.self,
                HonorRecord.self
            )
        } catch {
            fatalError("Failed to create the SwiftData container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
