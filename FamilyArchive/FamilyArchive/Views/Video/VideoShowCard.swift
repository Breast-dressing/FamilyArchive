import Foundation
import SwiftUI
import UIKit

struct VideoHeroCard: View {
    let show: VideoShow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cover
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            Text(show.title)
                .font(.title2.bold())
                .lineLimit(2)

            Text(show.synopsis)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: 8) {
                Text(show.platform)
                Text("·")
                Text("\(show.episodeTitles.count) 集")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var cover: some View {
        if let data = show.coverData, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.quaternary)
                Image(systemName: "tv")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct VideoShowCard: View {
    let show: VideoShow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let data = show.coverData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.quaternary)
                        Image(systemName: "tv")
                            .font(.system(size: 30))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 220, height: 124)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(show.title)
                .font(.headline)
                .lineLimit(1)
            Text("\(show.episodeTitles.count) 集")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 220, alignment: .leading)
    }
}
