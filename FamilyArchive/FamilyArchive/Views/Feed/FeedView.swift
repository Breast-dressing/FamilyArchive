import SwiftData
import SwiftUI

struct FeedView: View {
    @Environment(DateFilterStore.self) private var dateFilter
    @Environment(RootAccessoryState.self) private var accessoryState

    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \FeedPost.createdAt, order: .reverse) private var posts: [FeedPost]

    @State private var selectedPlatform = ""
    @State private var isAccountsPresented = false

    private var scopedAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.feed.rawValue }
    }

    private var platforms: [String] {
        let unique = SocialPlatform.uniquePlatforms(from: scopedAccounts)
        return unique.isEmpty ? ["全部"] : unique
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
            guard dateFilter.filter.contains(post.createdAt) else { return false }
            guard !query.isEmpty else { return true }
            return post.caption.localizedCaseInsensitiveContains(query)
                || post.platform.localizedCaseInsensitiveContains(query)
        }
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
                    masonry
                }
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("动态来源", selection: sourceBinding) {
                        ForEach(platforms, id: \.self) { platform in
                            Text(platform).tag(platform)
                        }
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
                    .accessibilityLabel("账号")
                }
            }
            .sheet(isPresented: $isAccountsPresented) {
                AccountsView(scope: .feed)
            }
        }
    }

    private var masonry: some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(0..<2, id: \.self) { column in
                LazyVStack(spacing: 12) {
                    ForEach(posts(in: column)) { post in
                        NavigationLink {
                            FeedPostDetailView(post: post)
                        } label: {
                            FeedPostCard(post: post, mediaHeight: mediaHeight(for: post))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func posts(in column: Int) -> [FeedPost] {
        filteredPosts.enumerated()
            .filter { $0.offset % 2 == column }
            .map { $0.element }
    }

    private func mediaHeight(for post: FeedPost) -> CGFloat {
        let seed = post.id.uuidString.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return [190, 150, 220, 170][seed % 4]
    }
}
