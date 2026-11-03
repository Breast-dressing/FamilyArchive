import SwiftUI

/// 有歌时用 fullScreenCover 装 MeloX 的 NowPlayingView（带 zoom 转场）；
/// 空状态时用 sheet 装 EmptyNowPlayingView —— sheet 自带抓杆与下滑关闭，
/// 和参考截图一致，也不会把人关在页面里。
struct PlayerPresentationModifier: ViewModifier {
    @Binding var item: PlayerPresentation?
    let hasSong: Bool
    let transitionID: String
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if hasSong {
            content.fullScreenCover(item: $item) { _ in
                NowPlayingView()
                    .presentationBackground(.clear)
                    .presentationContentInteraction(.resizes)
                    .navigationTransition(
                        .zoom(sourceID: transitionID, in: namespace)
                    )
            }
        } else {
            content.sheet(item: $item) { _ in
                EmptyNowPlayingView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
    }
}
