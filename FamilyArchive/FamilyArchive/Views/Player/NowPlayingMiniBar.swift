import SwiftUI

/// 底部播放条：左侧长胶囊（封面 + 名字 + 控制按钮），右侧单独的「＋」。
/// 没有歌曲时胶囊显示占位封面与「未在播放」，点击胶囊进入播放器。
struct NowPlayingMiniBar: View {
    let onOpen: () -> Void
    let onPlus: () -> Void

    @Environment(PlayerStore.self) private var player

    private var song: Song? { player.currentSong }

    var body: some View {
        HStack(spacing: 10) {
            capsule
                .frame(maxWidth: .infinity, alignment: .leading)
            plusButton
                .fixedSize()
            Spacer(minLength: 0)
                .frame(width: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.leading, 16)
        .padding(.trailing, 7)
        .padding(.bottom, 4)
    }

    private var capsule: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    artwork
                    VStack(alignment: .leading, spacing: 1) {
                        Text(song?.name ?? "未在播放")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .layoutPriority(1)
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            controls
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var subtitle: String {
        guard let song else { return "尚未播放" }
        return song.artists.map(\.name).joined(separator: " / ")
    }

    private var artwork: some View {
        Group {
            if let url = song?.album?.artworkURL {
                ArtworkImage(url: url, cornerRadius: 8)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
            }
        }
        .frame(width: 34, height: 34)
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button {
                Task { await player.previous() }
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("上一首")

            Button {
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel(player.isPlaying ? "暂停" : "播放")

            Button {
                Task { await player.next() }
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("下一首")

            Button(action: onOpen) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .accessibilityLabel("播放列表")
        }
        .foregroundStyle(.primary)
        .buttonStyle(.plain)
        .disabled(song == nil)
    }

    private var plusButton: some View {
        Button(action: onPlus) {
            Image(systemName: "plus")
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("添加")
    }
}
