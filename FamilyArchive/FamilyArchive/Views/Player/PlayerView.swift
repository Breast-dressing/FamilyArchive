import SwiftUI
import UIKit

/// zoom 过渡共用的 source id。
enum PlayerTransition {
    static let source = "player.mini"
}

/// 全屏播放器：模糊封面背景、大封面、歌词、进度与播放控制。
struct PlayerView: View {
    @Environment(PlaybackStore.self) private var playback
    @Environment(\.dismiss) private var dismiss

    @State private var isQueuePresented = false
    @State private var scrubProgress: Double?

    var body: some View {
        ZStack {
            background
            VStack(spacing: 16) {
                header
                artwork
                titleRow
                LyricsView(
                    lines: playback.lyrics,
                    currentIndex: playback.currentLyricIndex
                ) { line in
                    playback.seek(to: line.time)
                }
                .frame(maxHeight: .infinity)
                progressRow
                controls
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .sheet(isPresented: $isQueuePresented) {
            PlaybackQueueView()
        }
        .statusBarHidden(false)
    }

    private var background: some View {
        ZStack {
            if let data = playback.current?.artwork, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 46)
                    .overlay(Color.black.opacity(0.35))
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [.black.opacity(0.85), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("收起播放器")

            Spacer()

            Text("正在播放")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Button {
                isQueuePresented = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("播放列表")
        }
        .padding(.top, 8)
    }

    private var artwork: some View {
        Group {
            if let data = playback.current?.artwork, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.12))
                    Image(systemName: "music.note")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        .padding(.top, 4)
    }

    private var titleRow: some View {
        VStack(spacing: 4) {
            Text(playback.current?.title ?? "还没有歌曲")
                .font(.title3.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(playback.current?.subtitle ?? "")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    private var progressRow: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { scrubProgress ?? playback.progress },
                    set: { scrubProgress = $0 }
                ),
                in: 0...1,
                onEditingChanged: { editing in
                    if !editing, let value = scrubProgress {
                        playback.seek(toProgress: value)
                        scrubProgress = nil
                    }
                }
            )
            .tint(.white)

            HStack {
                Text(PlaybackTime.text(currentTime))
                Spacer()
                Text(PlaybackTime.text(playback.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.white.opacity(0.65))
        }
    }

    private var currentTime: Double {
        if let scrubProgress, playback.duration > 0 {
            return playback.duration * scrubProgress
        }
        return playback.currentTime
    }

    private var controls: some View {
        HStack(spacing: 44) {
            Button { playback.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26, weight: .semibold))
            }
            .accessibilityLabel("上一首")

            Button { playback.toggle() } label: {
                Image(systemName: playback.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64, weight: .regular))
            }
            .accessibilityLabel(playback.isPlaying ? "暂停" : "播放")

            Button { playback.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26, weight: .semibold))
            }
            .accessibilityLabel("下一首")
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
    }
}

/// 歌词：当前行高亮、随播放自动居中、点按跳转。
struct LyricsView: View {
    let lines: [LyricLine]
    let currentIndex: Int?
    let onSelect: (LyricLine) -> Void

    var body: some View {
        Group {
            if lines.isEmpty {
                Text("暂无歌词")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 18) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { offset, line in
                                Text(line.text.isEmpty ? " " : line.text)
                                    .font(offset == currentIndex
                                          ? .title3.weight(.bold)
                                          : .body.weight(.medium))
                                    .foregroundStyle(
                                        offset == currentIndex
                                            ? Color.white
                                            : Color.white.opacity(0.45)
                                    )
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity)
                                    .animation(.easeInOut(duration: 0.25), value: currentIndex)
                                    .onTapGesture { onSelect(line) }
                                    .id(offset)
                            }
                        }
                        .padding(.vertical, 120)
                    }
                    .onChange(of: currentIndex) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                    .onAppear {
                        if let currentIndex {
                            proxy.scrollTo(currentIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}
