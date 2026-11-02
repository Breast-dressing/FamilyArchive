import SwiftUI
import UIKit

/// 底部播放条：封面 → 名称 → 上一首 / 播放暂停 / 下一首 / 播放列表，
/// 右侧单独一个 ＋。点击非按钮区域用 zoom 进入播放器。
struct MiniPlayerBar: View {
    let namespace: Namespace.ID
    let onOpenPlayer: () -> Void
    let onPlusTap: () -> Void

    @Environment(PlaybackStore.self) private var playback
    @State private var isQueuePresented = false

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                playerCapsule
                plusButton
            }
        }
        .padding(.horizontal, BottomToolbarLayout.horizontalInset)
        .padding(.bottom, 6)
        .sheet(isPresented: $isQueuePresented) {
            PlaybackQueueView()
        }
    }

    private var playerCapsule: some View {
        HStack(spacing: 10) {
            Button(action: onOpenPlayer) {
                HStack(spacing: 10) {
                    artwork
                    VStack(alignment: .leading, spacing: 1) {
                        Text(playback.current?.title ?? "还没有歌曲")
                            .font(.footnote.weight(.semibold))
                            .lineLimit(1)
                        Text(playback.current?.subtitle ?? "点击 ＋ 导入音频")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: PlayerTransition.source, in: namespace)
            .accessibilityLabel("打开播放器")

            controls
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: Capsule())
    }

    private var artwork: some View {
        Group {
            if let data = playback.current?.artwork, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button(action: { playback.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .accessibilityLabel("上一首")

            Button(action: { playback.toggle() }) {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 22)
            }
            .accessibilityLabel(playback.isPlaying ? "暂停" : "播放")

            Button(action: { playback.next() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .semibold))
            }
            .accessibilityLabel("下一首")

            Button(action: { isQueuePresented = true }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 14, weight: .semibold))
            }
            .accessibilityLabel("播放列表")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .disabled(playback.queue.isEmpty)
    }

    private var plusButton: some View {
        Button(action: onPlusTap) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 20, height: 20)
                .padding(12)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("添加")
    }
}

/// 播放列表面板，播放条与播放器共用。
struct PlaybackQueueView: View {
    @Environment(PlaybackStore.self) private var playback
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(playback.queue.enumerated()), id: \.offset) { offset, item in
                    Button {
                        playback.select(offset)
                        playback.play()
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(offset + 1)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.body)
                                Text(item.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            if offset == playback.index {
                                Image(systemName: "waveform")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("播放列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
