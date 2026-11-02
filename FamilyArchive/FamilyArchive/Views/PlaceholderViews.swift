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
