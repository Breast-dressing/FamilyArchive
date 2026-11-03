import SwiftUI

/// 空状态播放条：没有歌曲时也占住底部附件的位置，
/// 点一下就能进播放器（不因为没歌而掐断入口）。
struct EmptyPlayerBar: View {
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.quaternary)
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("未在播放")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("点此打开播放器")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("打开播放器")
    }
}
