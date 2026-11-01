import SwiftData
import SwiftUI

struct VideoView: View {
    @Environment(RootAccessoryState.self) private var accessoryState

    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \VideoShow.createdAt, order: .reverse) private var shows: [VideoShow]

    @State private var selectedPlatform = ""
    @State private var selectedTag = TopCategoryPage.video.defaultTag
    @State private var isSearchActive = false
    @FocusState private var isSearchFocused: Bool

    private var scopedAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.video.rawValue }
    }

    private var platforms: [String] {
        SourceOptions.options(from: SocialPlatform.uniquePlatforms(from: scopedAccounts))
    }

    private var effectivePlatform: String {
        platforms.contains(selectedPlatform) ? selectedPlatform : (platforms.first ?? "全部")
    }

    private var filteredShows: [VideoShow] {
        let scoped = scopedAccounts.isEmpty
            ? shows
            : shows.filter { $0.platform == effectivePlatform }
        let query = accessoryState.videoSearchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return scoped.filter { show in
            guard VideoFilter.matches(show, tag: selectedTag) else { return false }
            guard !query.isEmpty else { return true }
            return show.title.localizedCaseInsensitiveContains(query)
                || show.synopsis.localizedCaseInsensitiveContains(query)
                || show.cast.localizedCaseInsensitiveContains(query)
                || show.platform.localizedCaseInsensitiveContains(query)
        }
    }

    private var videoSearchText: Binding<String> {
        Binding(
            get: { accessoryState.videoSearchText },
            set: { accessoryState.videoSearchText = $0 }
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
                if filteredShows.isEmpty {
                    ContentUnavailableView(
                        "暂无影视",
                        systemImage: "tv",
                        description: Text("点击下方 ＋ 添加影视内容。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 420)
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        if let featured = filteredShows.first {
                            VideoHeroCard(show: featured)
                                .padding(.horizontal)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("全部影视")
                                .font(.title2.bold())
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(filteredShows) { show in
                                        VideoShowCard(show: show)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if isSearchActive {
                        ToolbarSearchField(
                            text: videoSearchText,
                            focus: $isSearchFocused
                        )
                        .frame(minWidth: 160)
                    } else {
                        TopCategoryTabs(page: .video, selection: $selectedTag)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    TopActionGroup(
                        page: .video,
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
                    accessoryState.videoSearchText = ""
                }
            }
        }
    }
}
