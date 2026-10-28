import SwiftUI
import UIKit

struct FeedPostDetailView: View {
    let post: FeedPost

    @Environment(AppRouter.self) private var router

    private var title: String {
        let trimmed = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = trimmed.split(separator: "\n").first {
            let value = String(firstLine).trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { return value }
        }
        return post.platform
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(post.mediaData.indices, id: \.self) { index in
                    media(at: index)
                }

                Text(title)
                    .font(.title2.bold())

                if !post.caption.isEmpty {
                    Text(post.caption)
                        .font(.body)
                        .foregroundStyle(.primary)
                }

                Text(post.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(post.createdAt, format: .dateTime.year().month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("动态详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            router.isFeedDetailActive = true
        }
        .onDisappear {
            router.isFeedDetailActive = false
        }
    }

    @ViewBuilder
    private func media(at index: Int) -> some View {
        if index < post.mediaIsVideo.count, post.mediaIsVideo[index] {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.quaternary)
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
            .frame(height: 220)
        } else if index < post.mediaData.count,
                  let image = UIImage(data: post.mediaData[index]) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
