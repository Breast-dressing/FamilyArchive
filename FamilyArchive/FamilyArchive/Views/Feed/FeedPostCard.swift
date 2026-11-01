import Foundation
import SwiftUI
import UIKit

/// 单列信息流里的一条动态：九宫格媒体在上，左下角标题、右下角时间 + 发布者 +
/// 来源图标在下。
struct FeedPostCard: View {
    let post: FeedPost

    private var columns: Int {
        MediaGridRules.columns(for: post.mediaData.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            mediaGrid
            footer
        }
    }

    @ViewBuilder
    private var mediaGrid: some View {
        if post.mediaData.isEmpty {
            EmptyView()
        } else {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(), spacing: 4),
                    count: columns
                ),
                spacing: 4
            ) {
                ForEach(Array(post.mediaData.enumerated()), id: \.offset) { index, data in
                    mediaCell(
                        data: data,
                        isVideo: post.mediaIsVideo.indices.contains(index)
                            && post.mediaIsVideo[index]
                    )
                }
            }
        }
    }

    private func mediaCell(data: Data, isVideo: Bool) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if isVideo || UIImage(data: data) == nil {
                    Image(systemName: "play.rectangle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                } else if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(post.displayTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(FeedFooter.timeText(for: post.createdAt))
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !post.author.isEmpty {
                Text(post.author)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Image(systemName: FeedSourceIcon.symbol(for: post.platform))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel(post.platform)
        }
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }
}
