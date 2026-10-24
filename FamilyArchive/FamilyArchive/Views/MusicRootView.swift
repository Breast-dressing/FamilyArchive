import SwiftUI

struct MusicRootView: View {
    @Environment(AppRouter.self) private var router
    @State private var isAccountsPresented = false

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.musicPath) {
            ZStack {
                MusicHomeView()
                    .opacity(router.musicSection == .music ? 1 : 0)
                    .allowsHitTesting(router.musicSection == .music)

                ArchiveView()
                    .opacity(router.musicSection == .archive ? 1 : 0)
                    .allowsHitTesting(router.musicSection == .archive)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("音乐分区", selection: $router.musicSection) {
                        Text("音乐").tag(MusicSection.music)
                        Text("我的").tag(MusicSection.archive)
                    }
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .padding(.horizontal, 8)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAccountsPresented = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("账号")
                }
            }
            .sheet(isPresented: $isAccountsPresented) {
                AccountsView(scope: .music)
            }
            .navigationDestination(for: String.self) { familyURL in
                FamilyDetailView(familyURL: familyURL)
            }
        }
    }
}
