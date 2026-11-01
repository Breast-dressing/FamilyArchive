import SwiftData
import SwiftUI

struct MusicRootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(RootAccessoryState.self) private var accessoryState

    @Query(sort: \Account.createdAt) private var accounts: [Account]

    @State private var selectedTag = TopCategoryPage.music.defaultTag
    @State private var selectedPlatform = ""
    @State private var isSearchActive = false
    @State private var isAccountsPresented = false
    @Namespace private var accountsNamespace
    @FocusState private var isSearchFocused: Bool

    private var scopedAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.music.rawValue }
    }

    private var platforms: [String] {
        SourceOptions.options(from: SocialPlatform.uniquePlatforms(from: scopedAccounts))
    }

    private var sourceBinding: Binding<String> {
        Binding(
            get: {
                platforms.contains(selectedPlatform) ? selectedPlatform : SourceOptions.all
            },
            set: { selectedPlatform = $0 }
        )
    }

    private var musicSearchText: Binding<String> {
        Binding(
            get: { accessoryState.musicSearchText },
            set: { accessoryState.musicSearchText = $0 }
        )
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.musicPath) {
            VStack(spacing: 8) {
                // 分区切换在页面内，顶部只留给分类 Tab；档案分区在第 5、6 步迁到个人页后移除。
                Picker("分区", selection: $router.musicSection) {
                    Text("音乐").tag(MusicSection.music)
                    Text("我的").tag(MusicSection.archive)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ZStack {
                    MusicHomeView()
                        .opacity(router.musicSection == .music ? 1 : 0)
                        .allowsHitTesting(router.musicSection == .music)

                    ArchiveView()
                        .opacity(router.musicSection == .archive ? 1 : 0)
                        .allowsHitTesting(router.musicSection == .archive)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if isSearchActive {
                        ToolbarSearchField(
                            text: musicSearchText,
                            focus: $isSearchFocused
                        )
                        .frame(minWidth: 160)
                    } else {
                        TopCategoryTabs(page: .music, selection: $selectedTag)
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    TopActionGroup(
                        page: .music,
                        isSearchActive: isSearchActive,
                        sources: platforms,
                        selectedSource: sourceBinding,
                        onSearchTapped: { isSearchActive.toggle() }
                    )

                    // iOS 27 把所有 trailing toolbar item 合并成一枚玻璃胶囊，
                    // 用分隔线把「搜索 + 来源」与「账号」分成两组。
                    Divider()
                        .frame(height: 20)

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
            .onChange(of: isSearchActive) { _, active in
                isSearchFocused = active
                if !active {
                    accessoryState.musicSearchText = ""
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
