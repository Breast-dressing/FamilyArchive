import Foundation
import SwiftUI
import UIKit

/// 影视页顶部：左侧横向大图，右侧竖排「待播 / 待拍」计数。
struct VideoBanner: View {
    let show: VideoShow?

    var body: some View {
        Group {
            if let data = show?.coverData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "tv")
                        .font(.system(size: 42))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(alignment: .bottomLeading) {
            if let show {
                VStack(alignment: .leading, spacing: 2) {
                    Text(show.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(show.category)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .padding(10)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(show.map { "\($0.category)·\($0.title)" } ?? "暂无影视")
    }
}

/// 顶部右侧的状态计数块。
struct VideoStatPill: View {
    let title: String
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title3.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 76)
        .background(
            .quaternary.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)\(count)部")
    }
}

/// 双列小图：上方横向封面，左下剧名、右下来源图标。
struct VideoTile: View {
    let show: VideoShow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let data = show.coverData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        Rectangle().fill(.quaternary)
                        Image(systemName: "tv")
                            .font(.system(size: 26))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(show.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: FeedSourceIcon.symbol(for: show.platform))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(show.platform)
            }
            .padding(.horizontal, 2)
        }
    }
}
