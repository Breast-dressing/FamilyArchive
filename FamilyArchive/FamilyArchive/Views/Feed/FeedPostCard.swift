import Foundation
import SwiftUI
import UIKit

struct FeedPostCard: View {
    let post: FeedPost
    let mediaHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            media

            HStack(spacing: 6) {
                Text(post.platform)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Text(post.createdAt, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if post.mediaData.count > 1 {
                Text("共 \(post.mediaData.count) 个媒体")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    @ViewBuilder
    private var media: some View {
        if let first = post.mediaData.first {
            if post.mediaIsVideo.first == true || UIImage(data: first) == nil {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}
