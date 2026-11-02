import SwiftUI
import UIKit

/// zoom 过渡共用的 source id。
enum PlayerTransition {
    static let source = "player.mini"
}

/// 播放器的三个面板：只有封面是默认态，歌词 / 队列由底部按钮切换。
enum PlayerPanel {
    case cover
    case lyrics
    case queue
}

/// 播放器，按参考截图复刻：
/// 抓杆 → 方形封面 → 未在播放 → 进度条 + 虚线时间 → 上一首 / 播放 / 下一首
/// → 分隔线 → 音量 → 歌词 / AirPlay / 队列 三个按钮。
///
/// 点歌词按钮时封面用 matchedGeometry 收成左上角小图，歌词内容在原位展开；
/// 再点一次回到封面。
struct PlayerView: View {
    @Environment(PlaybackStore.self) private var playback

    @Namespace private var artworkNamespace

    @State private var panel: PlayerPanel

    init(initialPanel: PlayerPanel = .cover) {
        _panel = State(initialValue: initialPanel)
    }
    @State private var document: LyricsDocument = .empty
    @State private var isLoadingLyrics = false

    private var currentIndex: Int? {
        LyricsAnimation.currentIndex(in: document.lines, at: playback.currentTime)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if panel == .cover {
                    coverPanel
                } else {
                    expandedPanel
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            progressSection
            transportRow
            separator
            volumeRow
            bottomBar
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 6)
        .background(backdrop)
        .environment(\.colorScheme, .dark)
        .presentationDragIndicator(.visible)
        .task(id: playback.current?.id) { await loadLyrics() }
    }

    // MARK: - 背景

    private var backdrop: some View {
        ZStack {
            Color.black.opacity(0.55)
            if let data = playback.current?.artwork, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 40)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - 封面态

    private var coverPanel: some View {
        VStack(alignment: .leading, spacing: 26) {
            artworkTile
                .matchedGeometryEffect(id: "artwork", in: artworkNamespace)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)

            Text(statusTitle)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.top, 26)
    }

    // MARK: - 歌词 / 队列态

    private var expandedPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                artworkTile
                    .matchedGeometryEffect(id: "artwork", in: artworkNamespace)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.top, 18)

            if panel == .lyrics {
                lyricsPanel
            } else {
                queuePanel
            }
        }
    }

    private var lyricsPanel: some View {
        Group {
            if isLoadingLyrics, document.lines.isEmpty {
                centeredHint("正在获取歌词…")
            } else if document.lines.isEmpty {
                centeredHint("没有找到歌词")
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            ForEach(Array(document.lines.enumerated()), id: \.offset) { offset, line in
                                Text(line.text.isEmpty ? "♪" : line.text)
                                    .font(
                                        offset == currentIndex
                                            ? .system(size: 21, weight: .bold)
                                            : .system(size: 18, weight: .regular)
                                    )
                                    .foregroundStyle(
                                        offset == currentIndex
                                            ? Color.white.opacity(0.95)
                                            : Color.white.opacity(0.4)
                                    )
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(offset)
                                    .onTapGesture { playback.seek(to: line.time) }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: currentIndex) { _, newValue in
                        guard let newValue else { return }
                        withAnimation(.easeInOut(duration: 0.35)) {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var queuePanel: some View {
        Group {
            if playback.queue.isEmpty {
                centeredHint("队列中无音乐。")
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(playback.queue.enumerated()), id: \.offset) { offset, item in
                            Button {
                                playback.select(offset)
                            } label: {
                                HStack(spacing: 12) {
                                    Text("\(offset + 1)")
                                        .font(.system(size: 13).monospacedDigit())
                                        .foregroundStyle(.white.opacity(0.4))
                                        .frame(width: 20, alignment: .trailing)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.title)
                                            .font(.system(size: 16, weight: .semibold))
                                        Text(item.subtitle)
                                            .font(.system(size: 12))
                                            .foregroundStyle(.white.opacity(0.45))
                                    }
                                    Spacer(minLength: 0)
                                    if offset == playback.index {
                                        Image(systemName: "waveform")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 进度

    private var progressSection: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.24))
                    Capsule()
                        .fill(.white.opacity(0.75))
                        .frame(width: proxy.size.width * playback.progress)
                }
            }
            .frame(height: 4)

            HStack {
                Text(timeLabel(playback.currentTime))
                Spacer()
                Text(timeLabel(playback.duration))
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundStyle(.white.opacity(0.45))
        }
        .padding(.bottom, 18)
    }

    private func timeLabel(_ seconds: Double) -> String {
        playback.duration > 0 ? PlaybackTime.text(seconds) : "- -:- -"
    }

    // MARK: - 上一首 / 播放 / 下一首

    private var transportRow: some View {
        HStack {
            Button { playback.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26, weight: .medium))
                    .frame(width: 60, height: 60)
            }
            .accessibilityLabel("上一首")

            Spacer()

            Button { playback.toggle() } label: {
                Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 30, weight: .medium))
                    .frame(width: 68, height: 68)
            }
            .accessibilityLabel(playback.isPlaying ? "暂停" : "播放")

            Spacer()

            Button { playback.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26, weight: .medium))
                    .frame(width: 60, height: 60)
            }
            .accessibilityLabel("下一首")
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.bottom, 18)
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.1))
            .frame(height: 1)
    }

    // MARK: - 音量

    private var volumeRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))

            Slider(
                value: Binding(
                    get: { playback.volume },
                    set: { playback.volume = $0 }
                ),
                in: 0...1
            )
            .tint(.white.opacity(0.6))

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.vertical, 18)
    }

    // MARK: - 底部三按钮

    private var bottomBar: some View {
        HStack {
            panelButton(target: .lyrics, systemImage: "text.bubble")
            Spacer()
            panelButton(target: .queue, systemImage: "list.bullet")
        }
        .padding(.horizontal, 54)
        .padding(.bottom, 6)
    }

    private func panelButton(target: PlayerPanel, systemImage: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                panel = panel == target ? .cover : target
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white.opacity(panel == target ? 0.95 : 0.55))
                .frame(width: 44, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(panel == target ? 0.14 : 0))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(target == .lyrics ? "歌词" : "播放列表")
    }

    // MARK: - 文案

    private var statusTitle: String {
        playback.current?.title ?? "未在播放"
    }

    private var subtitle: String {
        playback.current?.subtitle ?? "队列中无音乐。"
    }

    private func centeredHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 封面占位

    private var artworkTile: some View {
        Group {
            if let data = playback.current?.artwork, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.white.opacity(0.06))
                    Image(systemName: "music.note")
                        .font(.system(size: 96, weight: .regular))
                        .foregroundStyle(.white.opacity(0.12))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
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
            source: .qqMusic
        )
        if !fetched.isEmpty {
            document = fetched
        } else if local.isEmpty {
            document = .empty
        }
    }
}
