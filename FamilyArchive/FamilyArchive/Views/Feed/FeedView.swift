import SwiftData
import SwiftUI

struct FeedView: View {
    @Environment(DateFilterStore.self) private var dateFilter
    @Environment(RootAccessoryState.self) private var accessoryState

    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \FeedPost.createdAt, order: .reverse) private var posts: [FeedPost]

    @State private var selectedPlatform = ""
    @State private var selectedTag = TopCategoryPage.feed.defaultTag
    @State private var isSearchActive = false
    @FocusState private var isSearchFocused: Bool

    private var scopedAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.feed.rawValue }
    }

    private var platforms: [String] {
        SourceOptions.options(from: SocialPlatform.uniquePlatforms(from: scopedAccounts))
    }

    private var effectivePlatform: String {
        platforms.contains(selectedPlatform) ? selectedPlatform : (platforms.first ?? "全部")
    }

    private var filteredPosts: [FeedPost] {
        let scoped = scopedAccounts.isEmpty
            ? posts
            : posts.filter { $0.platform == effectivePlatform }
        let query = accessoryState.feedSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return scoped.filter { post in
            guard FeedFilter.matches(post, tag: selectedTag) else { return false }
            guard dateFilter.filter.contains(post.createdAt) else { return false }
            guard !query.isEmpty else { return true }
            return post.caption.localizedCaseInsensitiveContains(query)
                || post.platform.localizedCaseInsensitiveContains(query)
        }
    }

    private var feedSearchText: Binding<String> {
        Binding(
            get: { accessoryState.feedSearchText },
            set: { accessoryState.feedSearchText = $0 }
        )
    }

    private var sourceBinding: Binding<String> {
        Binding(
            get: { effectivePlatform },
            set: { selectedPlatform = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if filteredPosts.isEmpty {
                    ContentUnavailableView(
                        "暂无动态",
                        systemImage: "square.stack.3d.up",
                        description: Text("点击下方 ＋ 发布第一条动态。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    feedList
                }
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if isSearchActive {
                        ToolbarSearchField(
                            text: feedSearchText,
                            focus: $isSearchFocused
                        )
                        .frame(minWidth: 160)
                    } else {
                        TopCategoryTabs(page: .feed, selection: $selectedTag)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    TopActionGroup(
                        page: .feed,
                        isSearchActive: isSearchActive,
                        sources: platforms,
                        selectedSource: sourceBinding,
                        onSearchTapped: { isSearchActive.toggle() }
                    )
                }
            }
            .onChange(of: isSearchActive) { _, active in
                isSearchFocused = active
                if !active {
                    accessoryState.feedSearchText = ""
                }
            }
        }
    }

    /// 单列信息流：一条动态一条卡片，媒体走九宫格。
    private var feedList: some View {
        LazyVStack(spacing: 18) {
            ForEach(filteredPosts) { post in
                NavigationLink {
                    FeedPostDetailView(post: post)
                } label: {
                    FeedPostCard(post: post)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
