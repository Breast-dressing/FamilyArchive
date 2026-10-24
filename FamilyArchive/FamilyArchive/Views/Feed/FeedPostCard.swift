import Foundation
import SwiftUI
import UIKit

struct FeedPostCard: View {
    let post: FeedPost
    let mediaHeight: CGFloat

    private var title: String {
        let trimmed = post.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = trimmed.split(separator: "\n").first {
            let value = String(firstLine).trimmingCharacters(in: .whitespaces)
            if !value.isEmpty { return value }
        }
        return post.platform
    }

    private var dayLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: post.createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(dayLabel)
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline.bold())
                .foregroundStyle(.primary)
                .lineLimit(2)

            media

            HStack(spacing: 6) {
                Text(post.platform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if post.mediaData.count > 1 {
                    Text("\(post.mediaData.count) 个媒体")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    @ViewBuilder
    private var media: some View {
        if let first = post.mediaData.first {
            if post.mediaIsVideo.first == true || UIImage(data: first) == nil {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.quaternary)
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.secondary)
                }
                .frame(height: mediaHeight)
            } else if let image = UIImage(data: first) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: mediaHeight)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }
}
