import SwiftUI

struct MusicRootView: View {
    @Environment(AppRouter.self) private var router
    @State private var isAccountsPresented = false
    @Namespace private var accountsNamespace

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
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("音乐分区", selection: $router.musicSection) {
                        Text("音乐").tag(MusicSection.music)
                        Text("我的").tag(MusicSection.archive)
                    }
                    .pickerStyle(.segmented)
                    .frame(minWidth: 140)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAccountsPresented = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .matchedTransitionSource(
                        id: AccountsTransitionSource.sourceID(for: .music),
                        in: accountsNamespace
                    )
                    .accessibilityLabel("账号")
                }
            }
            .sheet(isPresented: $isAccountsPresented) {
                AccountsView(scope: .music)
                    .navigationTransition(
                        .zoom(
                            sourceID: AccountsTransitionSource.sourceID(for: .music),
                            in: accountsNamespace
                        )
                    )
            }
            .navigationDestination(for: MusicRoute.self) { route in
                switch route {
                case .family(let familyURL):
                    FamilyDetailView(familyURL: familyURL)
                case .member(let familyURL, let memberID):
                    MemberDetailView(familyURL: familyURL, memberID: memberID)
                case .fans:
                    FansSkinsView()
                case .medals:
                    MedalHallView()
                case .cards:
                    LyricCardsView()
                }
            }
        }
    }
}
