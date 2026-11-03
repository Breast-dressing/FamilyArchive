import SwiftUI

/// 播放条贴在 Tab 栏正上方的底部区域。
///
/// 用 `.safeAreaInset` 而不是 `.toolbar(placement: .bottomBar)`：
/// 实测 toolbar 版本无法把内容拉到屏幕右缘（右侧永远少约 30pt）。
/// 横向边距由 `NowPlayingMiniBar` 按系统 TabBar 玻璃面板的实测值
/// （iPhone 21pt / iPad 20pt）设置，左右各与 TabBar 对齐。
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
