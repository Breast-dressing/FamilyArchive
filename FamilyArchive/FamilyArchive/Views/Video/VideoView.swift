import SwiftData
import SwiftUI

struct VideoView: View {
    @Query(sort: \Account.createdAt) private var accounts: [Account]
    @Query(sort: \VideoShow.createdAt, order: .reverse) private var shows: [VideoShow]

    @State private var selectedPlatform = ""
    @State private var isAccountsPresented = false

    private var scopedAccounts: [Account] {
        accounts.filter { $0.scope == AccountScope.video.rawValue }
    }

    private var platforms: [String] {
        let unique = SocialPlatform.uniquePlatforms(from: scopedAccounts)
        return unique.isEmpty ? ["全部"] : unique
    }

    private var effectivePlatform: String {
        platforms.contains(selectedPlatform) ? selectedPlatform : (platforms.first ?? "全部")
    }

    private var filteredShows: [VideoShow] {
        if scopedAccounts.isEmpty {
            return shows
        }
        return shows.filter { $0.platform == effectivePlatform }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarRole(.editor)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("影视来源", selection: sourceBinding) {
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
                AccountsView(scope: .video)
            }
        }
    }
}
