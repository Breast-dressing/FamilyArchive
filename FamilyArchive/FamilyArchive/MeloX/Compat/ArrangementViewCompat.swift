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

    @Environment(\.splitArrangementRatio) private var environmentSplitRatio

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
                        .frame(
                            width: proxy.size.width
                                * (environmentSplitRatio ?? splitRatio)
                        )
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

// MARK: - iOS 27.1 SDK 缺失的修饰符

private struct SplitArrangementRatioKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var splitArrangementRatio: CGFloat? {
        get { self[SplitArrangementRatioKey.self] }
        set { self[SplitArrangementRatioKey.self] = newValue }
    }
}

extension View {
    /// iOS 27.1 的 `ArrangementView` 子视图配比修饰符；在低版本 SDK 上用环境值携带。
    func splitArrangementLayoutRatio(_ ratio: CGFloat) -> some View {
        environment(\.splitArrangementRatio, ratio)
    }
}

/// iOS 27.1 的 toolbar 轴向偏好；27.0 SDK 上按默认行为处理。
enum ToolbarAxisBehavior {
    case verticalPreferred
    case horizontalPreferred
    case automatic
}

extension ToolbarItem {
    func axisBehavior(_ behavior: ToolbarAxisBehavior) -> Self {
        self
    }
}

// MARK: - iOS 27.1 的折叠屏分区查询

/// iOS 27.1 的预留区域（折叠屏分区等）。27.0 SDK 上恒为空。
struct ReservedRegion: Equatable {}

enum ReservedRegionKind {
    case division
}

struct ReservedRegionOptions: OptionSet {
    let rawValue: Int

    static let includeInactive = ReservedRegionOptions(rawValue: 1 << 0)
}

extension GeometryProxy {
    func reservedRegions(
        kind: ReservedRegionKind,
        options: ReservedRegionOptions = []
    ) -> [ReservedRegion] {
        []
    }
}
