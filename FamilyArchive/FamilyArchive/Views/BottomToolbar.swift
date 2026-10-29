//
//  BottomToolbar.swift
//  FamilyArchive
//
//  Floating liquid-glass toolbar modelled on the iOS 27 Notes toolbar: one long
//  capsule on the leading edge and independent glass circles on the trailing
//  edge. The leading control is the system search field itself.
//

import SwiftUI

/// A control rendered by the floating bottom toolbar.
enum BottomToolbarControl: String, CaseIterable, Hashable, Sendable {
    case search
    case date
    case plus
}

/// The toolbar order is a hard requirement: 搜索 → 日期筛选 → ＋.
///
/// It is a pure value so the invariant can be covered by a logic test instead of
/// a UI test, and it never changes with the selected tab, the search state or the
/// shape a control happens to render in.
enum BottomToolbarLayout {
    static let controls: [BottomToolbarControl] = [.search, .date, .plus]

    /// Every tab renders the same locked order.
    static func controls(for tab: RootTab) -> [BottomToolbarControl] {
        controls
    }

    /// Horizontal inset shared by the floating toolbar and the floating tab bar
    /// so both edges line up on the same vertical grid.
    static let horizontalInset: CGFloat = 21

    /// The toolbar's controls use the same 44pt hit area as the circular
    /// buttons in the page's NavigationBar, so the top and bottom chrome read
    /// as one system.
    static let controlSize: CGFloat = 44

    // MARK: - Presence

    /// 更多 has no 搜索 / 日期筛选 / ＋, so the floating bar leaves that page.
    /// Every other tab keeps it.
    static func isVisible(for tab: RootTab) -> Bool {
        tab != .more
    }

    /// How far the bar travels on its way out. It has to clear its own height and
    /// sink behind the tab bar; the space the bar reserves in the safe area does
    /// not move, so nothing else on the page shifts while it leaves.
    static let exitTravel: CGFloat = 96

    /// The spring a tab change already uses, so the bar starts and settles
    /// together with the tab bar instead of running a curve of its own.
    static let exitAnimation: Animation = .spring(response: 0.42, dampingFraction: 0.86)

    /// The bar's presence as one continuous number: 1 fully on screen, 0 gone.
    ///
    /// Offset and opacity are both derived from it, so they can never disagree,
    /// and because the value is animated (never inserted or removed) a reversal
    /// mid-flight retargets from wherever the bar currently is instead of
    /// replaying a fixed transition from the start.
    static func progress(forVisible visible: Bool) -> Double {
        visible ? 1 : 0
    }

    static func offset(progress: Double) -> CGFloat {
        (1 - clamped(progress)) * exitTravel
    }

    static func opacity(progress: Double) -> Double {
        clamped(progress)
    }

    private static func clamped(_ progress: Double) -> Double {
        min(max(progress, 0), 1)
    }
}

/// Custom bottom toolbar that replaces the previous detached "＋" tab and the
/// `tabViewBottomAccessory`. Rendered above the native tab bar in 动态 / 影视 /
/// 音乐; every tab shows the same left-to-right control order.
struct BottomToolbar: View {
    let tab: RootTab
    let dateLabel: String
    let namespace: Namespace.ID
    @Binding var searchText: String
    var focus: FocusState<Bool>.Binding
    let onSearchSubmit: () -> Void
    let onDateTap: () -> Void
    let onPlusTap: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(BottomToolbarLayout.controls(for: tab), id: \.self) { control in
                    controlView(control)
                }
            }
        }
        .padding(.horizontal, BottomToolbarLayout.horizontalInset)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private func controlView(_ control: BottomToolbarControl) -> some View {
        switch control {
        case .search:
            searchControl
        case .date:
            dateControl
        case .plus:
            plusControl
        }
    }

    // MARK: - Leading capsule (native search)

    /// The system search field keeps its intrinsic height, typography and
    /// glyphs; only the surrounding glass is ours.
    private var searchControl: some View {
        ToolbarSearchField(text: $searchText, focus: focus, onSubmit: onSearchSubmit)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular.interactive(), in: Capsule())
            .accessibilityLabel("搜索")
    }

    // MARK: - Trailing circles (date, plus)

    private var dateControl: some View {
        Button(action: onDateTap) {
            glassIcon("calendar.badge.clock")
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: AccessoryTransition.dateFilter, in: namespace)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("日期筛选")
        .accessibilityValue(dateLabel)
    }

    private var plusControl: some View {
        Button(action: onPlusTap) {
            glassIcon("plus")
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: AccessoryTransition.plus, in: namespace)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("添加")
    }

    /// 44pt square hit area with a 20pt glyph, matching NavigationBar buttons.
    private func glassIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 20, height: 20)
            .padding(12)
            .contentShape(Circle())
    }
}
