import SwiftUI

/// 播放条贴在 Tab 栏正上方的底部区域。
///
/// 用 `.safeAreaInset` 而不是 `.toolbar(placement: .bottomBar)`：
/// 实测 toolbar 版本无法把内容拉到屏幕右缘（右侧永远少约 30pt），
/// 而 safeAreaInset 的左右边距与 TabView 完全一致（各 16pt）。
extension View {
    func bottomPlaybackToolbar(
        onOpen: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            NowPlayingMiniBar(onOpen: onOpen, onPlus: onPlus)
        }
    }
}
