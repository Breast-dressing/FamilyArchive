import SwiftData
import SwiftUI

/// Search presentation for the Feed accessory search button. The query text is
/// owned by RootAccessoryState, so it survives the sheet and tab changes.
struct FeedSearchView: View {
    @Binding var searchText: String

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FeedPost.createdAt, order: .reverse) private var posts: [FeedPost]

    private var filteredPosts: [FeedPost] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return posts }
        return posts.filter {
            $0.caption.localizedCaseInsensitiveContains(query)
                || $0.platform.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredPosts) { post in
                NavigationLink {
                    FeedPostDetailView(post: post)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.caption)
                            .font(.subheadline)
                            .lineLimit(3)

                        Text(post.platform)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
            .listStyle(.plain)
            .overlay {
                if filteredPosts.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "暂无动态",
                            systemImage: "square.stack.3d.up",
                            description: Text("发布动态后可以在这里搜索。")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .navigationTitle("搜索动态")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "搜索动态"
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}
