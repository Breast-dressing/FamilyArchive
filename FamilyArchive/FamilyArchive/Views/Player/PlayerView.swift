import SwiftUI
import UIKit

/// zoom 过渡共用的 source id。
enum PlayerTransition {
    static let source = "player.mini"
}

/// 全屏播放器：Lyricify Mobile 的交互重写 —— 封面点按播放 / 双击下一首、
/// 标题左右滑动切歌、逐字歌词填充、翻译、拖动效果与可调模糊。
struct PlayerView: View {
    @Environment(PlaybackStore.self) private var playback
    @Environment(PlayerSettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var document: LyricsDocument = .empty
    @State private var isLoadingLyrics = false
    @State private var isQueuePresented = false
    @State private var isSettingsPresented = false
    @State private var scrubProgress: Double?
    @State private var pullOffset: CGFloat = 0

    private var displayTime: Double {
        max(playback.currentTime + settings.latency, 0)
    }

    private var lines: [LyricLine] { document.lines }

    private var currentIndex: Int? {
        LyricsAnimation.currentIndex(in: lines, at: displayTime)
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 14) {
                header
                artwork
                titleRow
                lyrics
                progressRow
                controls
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .sheet(isPresented: $isQueuePresented) { PlaybackQueueView() }
        .sheet(isPresented: $isSettingsPresented) { PlayerSettingsView() }
        .task(id: playback.current?.id) { await loadLyrics() }
    }

    // MARK: - 背景

    private var background: some View {
        ZStack {
            if let data = playback.current?.artwork, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: settings.backgroundBlurRadius)
                    .overlay(Color.black.opacity(0.4))
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [.black.opacity(0.9), .black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
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

            HStack(spacing: 14) {
                Button { isSettingsPresented = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("播放器设置")

                Button { isQueuePresented = true } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("播放列表")
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 封面（点按播放，双击下一首）

    private var artwork: some View {
        Group {
            if let data = playback.current?.artwork, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
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
        .scaleEffect(1 - min(abs(pullOffset) / 1200, 0.08))
        .onTapGesture(count: 2) { playback.next() }
        .onTapGesture { playback.toggle() }
        .accessibilityLabel(playback.isPlaying ? "暂停" : "播放")
        .accessibilityHint("双击下一首")
    }

    // MARK: - 标题（左右滑动切歌）

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
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40 {
                        playback.next()
                    } else if value.translation.width > 40 {
                        playback.previous()
                    }
                }
        )
        .accessibilityHint("向左滑动下一首，向右滑动上一首")
    }

    // MARK: - 歌词

    private var lyrics: some View {
        LyricsView(
            document: document,
            currentIndex: currentIndex,
            time: displayTime,
            isLoading: isLoadingLyrics,
            settings: settings,
            onSelect: { line in
                playback.seek(to: max(line.time - settings.latency, 0))
            }
        )
        .frame(maxHeight: .infinity)
        .simultaneousGesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard settings.pullEffect else { return }
                    pullOffset = value.translation.height
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        pullOffset = 0
                    }
                }
        )
    }

    // MARK: - 进度

    private var progressRow: some View {
        VStack(spacing: 4) {
            if playback.duration > 0 {
                Slider(
                    value: Binding(
                        get: { scrubProgress ?? playback.progress },
                        set: { scrubProgress = $0 }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        guard !editing, let value = scrubProgress else { return }
                        playback.seek(toProgress: value)
                        scrubProgress = nil
                    }
                )
                .tint(.white)
            } else {
                Capsule()
                    .fill(.white.opacity(0.22))
                    .frame(height: 5)
            }

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

    // MARK: - 控制

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

    // MARK: - 歌词加载

    private func loadLyrics() async {
        guard let item = playback.current else {
            document = .empty
            return
        }
        isLoadingLyrics = true
        defer { isLoadingLyrics = false }

        let local = LRCParser.parse(item.lyricsText)
        if !local.isEmpty {
            document = LyricsDocument(lines: local)
        }

        let fetched = await LyricsService.load(
            title: item.title,
            artist: item.subtitle,
            localLyrics: item.lyricsText,
            source: settings.source
        )
        if !fetched.isEmpty {
            document = fetched
        } else if local.isEmpty {
            document = .empty
        }
    }
}

/// 歌词列表：当前行放大高亮、逐字填充、翻译、点按跳转、自动居中。
struct LyricsView: View {
    let document: LyricsDocument
    let currentIndex: Int?
    let time: Double
    let isLoading: Bool
    let settings: PlayerSettingsStore
    let onSelect: (LyricLine) -> Void

    var body: some View {
        Group {
            if document.lines.isEmpty {
                Text(isLoading ? "正在获取歌词…" : "没有找到歌词")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 16) {
                            ForEach(Array(document.lines.enumerated()), id: \.offset) { offset, line in
                                lineView(offset: offset, line: line)
                                    .id(offset)
                                    .onTapGesture { onSelect(line) }
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
        .animation(.easeInOut(duration: 0.25), value: currentIndex)
    }

    private func lineView(offset: Int, line: LyricLine) -> some View {
        let isCurrent = offset == currentIndex
        let nextStart = offset + 1 < document.lines.count
            ? document.lines[offset + 1].time
            : nil
        let progress = LyricsAnimation.fillProgress(
            for: line,
            at: time,
            nextStart: nextStart
        )

        return VStack(spacing: 4) {
            Text(line.text.isEmpty ? "♪" : line.text)
                .font(settings.lyricFont(current: isCurrent))
                .foregroundStyle(
                    isCurrent ? Color.white.opacity(0.28) : Color.white.opacity(0.5)
                )
                .overlay(alignment: .leading) {
                    if isCurrent {
                        GeometryReader { proxy in
                            Text(line.text.isEmpty ? "♪" : line.text)
                                .font(settings.lyricFont(current: true))
                                .foregroundStyle(.white)
                                .mask(alignment: .leading) {
                                    Rectangle()
                                        .frame(width: proxy.size.width * progress)
                                }
                        }
                    }
                }

            if settings.showTranslation,
               isCurrent,
               let translation = line.translation,
               !translation.isEmpty {
                Text(translation)
                    .font(settings.translationFont)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .scaleEffect(isCurrent ? 1.04 : 1)
        .opacity(isCurrent ? 1 : 0.85)
    }
}
