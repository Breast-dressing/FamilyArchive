import SwiftUI

/// 空状态播放器：严格对照参考截图复刻。
/// 抓杆 → 深灰方块占位封面（中间音符）→「未在播放」→ 灰色细进度条 + 虚线时间
/// → 上一首 / 播放 / 下一首 → 分隔线 → 音量条 → 底部三个图标（气泡 / 波纹 / 列表）。
struct EmptyNowPlayingView: View {
    @State private var volume: Double = 0.7

    var body: some View {
        ZStack {
            Color(white: 0.42).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 28)

                artwork
                    .padding(.horizontal, 40)

                Spacer(minLength: 12)

                title
                progressSection
                transportRow
                separator
                volumeRow
                bottomBar
            }
            .padding(.bottom, 8)
        }
        .environment(\.colorScheme, .dark)
    }

    private var artwork: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(white: 0.47))
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 140, weight: .regular))
                    .foregroundStyle(Color(white: 0.53))
            }
    }

    private var title: some View {
        Text("未在播放")
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.white.opacity(0.95))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(height: 5)
                .padding(.horizontal, 24)

            HStack {
                dashedTime
                Spacer()
                dashedTime
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 30)
    }

    private var dashedTime: some View {
        Text("- -:- -")
            .font(.system(size: 13, weight: .regular).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
            .lineLimit(1)
    }

    private var transportRow: some View {
        HStack {
            Image(systemName: "backward.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 72, height: 60)
            Spacer()
            Image(systemName: "play.fill")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 80, height: 60)
            Spacer()
            Image(systemName: "forward.fill")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 72, height: 60)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 26)
    }

    private var separator: some View {
        Rectangle()
            .fill(.white.opacity(0.14))
            .frame(height: 1)
            .padding(.horizontal, 24)
    }

    private var volumeRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "speaker.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.55))

            Capsule()
                .fill(.white.opacity(0.28))
                .frame(height: 5)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(.white.opacity(0.55))
                            .frame(width: proxy.size.width * volume)
                    }
                }
                .frame(height: 5)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            volume = min(max(value.location.x / 260, 0), 1)
                        }
                )

            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 22)
    }

    private var bottomBar: some View {
        HStack {
            Image(systemName: "text.bubble")
            Spacer()
            Image(systemName: "airplayaudio")
            Spacer()
            Image(systemName: "list.bullet")
        }
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 44)
        .padding(.bottom, 6)
    }
}
