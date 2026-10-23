import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "更多",
                systemImage: "ellipsis.circle",
                description: Text("更多功能正在准备中。")
            )
            .navigationTitle("更多")
        }
    }
}

struct MusicHomeView: View {
    var body: some View {
        ContentUnavailableView(
            "音乐",
            systemImage: "music.note",
            description: Text("切换到“档案”管理家族并导入家族记录文件。")
        )
    }
}
