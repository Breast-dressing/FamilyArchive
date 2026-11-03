//
//  BottomToolbar.swift
//  FamilyArchive
//
//  Metrics shared by the floating chrome. The old search / date / plus bar was
//  replaced by the playback bar in step 7; only the spacing constants remain.
//

import SwiftUI

enum BottomToolbarLayout {
    /// iOS 26/27 浮动 TabBar 的实测左右边距（iPhone、compact width）。
    ///
    /// 在 iPhone 18 Pro（402pt 宽、iOS 27.0）上实测系统的玻璃面板
    /// `_UITabBarItemPlatterView`：主胶囊 frame = x 21…311，detached 的
    /// `_UITabBarAuxiliaryView` = x 319…381。即整个 TabBar 的玻璃体所占的
    /// 横向范围就是 21…381，左右边距各 21pt。HIG 的 16pt 是屏幕内容卡片
    /// （列表、大图卡片）的边距，不是浮动 TabBar 玻璃体的边距；玻璃体外侧
    /// 那 5pt 露出的是内容本身，别拿 16pt 当作 TabBar 的边缘。
    ///
    /// 底部播放条用同一数值，左胶囊的左缘与“＋”的右缘就分别落在 TabBar
    /// 玻璃体的左右边缘上。数据来自 CI 模拟器导出的 `BottomChromeGeometry.json`。
    static let horizontalInset: CGFloat = 21

    /// iPad（regular width）上系统 TabBar 的左右边距为 20pt。
    static let regularHorizontalInset: CGFloat = 20

    /// The controls use the same 44pt hit area as the circular buttons in the
    /// page's NavigationBar, so the top and bottom chrome read as one system.
    static let controlSize: CGFloat = 44
}
