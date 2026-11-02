import SwiftUI

/// 音乐标签页：直接承载 MeloX 的 Explore 首页与它的 music 路由。
struct MeloXMusicTabHost: View {
    @Namespace private var musicNamespace

    var body: some View {
        NavigationStack {
            ExploreView(navigationTitle: "音乐")
                .musicDestinations(in: musicNamespace)
        }
        .environment(\.musicNavigationNamespace, musicNamespace)
    }
}
