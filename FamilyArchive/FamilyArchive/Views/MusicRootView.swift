import SwiftUI

struct MusicRootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.musicPath) {
            Group {
                if router.musicSection == .music {
                    MusicHomeView()
                } else {
                    ArchiveView()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("音乐分区", selection: $router.musicSection) {
                        Text("音乐").tag(MusicSection.music)
                        Text("档案").tag(MusicSection.archive)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    if router.musicSection == .archive {
                        Button("更多") {}
                    }

                    Button("账号") {}
                }
            }
            .navigationDestination(for: String.self) { familyURL in
                FamilyDetailView(familyURL: familyURL)
            }
        }
    }
}
