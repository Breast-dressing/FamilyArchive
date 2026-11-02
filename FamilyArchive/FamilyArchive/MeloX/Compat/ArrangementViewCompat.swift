//
//  ArrangementViewCompat.swift
//  FamilyArchive
//
//  CI 的 Xcode 27.0（iOS 27.0 SDK）里没有 iOS 27.1 才加入的 SwiftUI
//  `ArrangementView`，而 MeloX 的播放器用到它。这里提供同签名的兼容实现：
//  `.overlay` 走 ZStack（等价于 MeloX 自己的 iOS 27.0 兜底分支），
//  `.split` 走左右分栏。CI 升级到 27.1 SDK 后删掉本文件即可。
//

import SwiftUI

enum ArrangementViewStyle {
    case overlay
    case split
}

struct ArrangementView<Primary: View, Secondary: View>: View {
    let primary: Primary
    let secondary: Secondary

    private var style: ArrangementViewStyle = .overlay
    private var splitRatio: CGFloat = 0.5

    init(
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.primary = primary()
        self.secondary = secondary()
    }

    var body: some View {
        switch style {
        case .overlay:
            ZStack {
                secondary
                primary
            }
        case .split:
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    primary
                        .frame(width: proxy.size.width * splitRatio)
                    secondary
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    func arrangementViewStyle(_ style: ArrangementViewStyle) -> Self {
        var copy = self
        copy.style = style
        return copy
    }

    func splitArrangementLayoutRatio(_ ratio: CGFloat) -> Self {
        var copy = self
        copy.splitRatio = ratio
        return copy
    }
}
