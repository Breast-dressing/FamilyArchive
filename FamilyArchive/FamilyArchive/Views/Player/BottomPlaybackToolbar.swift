import SwiftUI

/// 把播放条放进底部工具栏（`.bottomBar`），而不是 `tabViewBottomAccessory`。
extension View {
    func bottomPlaybackToolbar(
        onOpen: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        self.toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack(spacing: 0) {
                    NowPlayingMiniBar(onOpen: onOpen, onPlus: onPlus)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .toolbarBackground(.hidden, for: .bottomBar)
    }
}
