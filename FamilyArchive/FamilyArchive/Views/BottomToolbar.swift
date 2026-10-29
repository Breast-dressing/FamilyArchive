//
//  BottomToolbar.swift
//  FamilyArchive
//
//  Floating liquid-glass toolbar modelled on the iOS 27 Notes toolbar: one long
//  capsule on the leading edge and independent glass circles on the trailing
//  edge.
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
}

/// Custom bottom toolbar that replaces the previous detached "＋" tab and the
/// `tabViewBottomAccessory`. Rendered above the native tab bar in 动态 / 影视 /
/// 音乐; every tab shows the same left-to-right control order.
struct BottomToolbar: View {
    let tab: RootTab
    let dateLabel: String
    let namespace: Namespace.ID
    @Binding var searchText: String
    let isSearchFieldActive: Bool
    var focus: FocusState<Bool>.Binding
    let onSearchTap: () -> Void
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
        .padding(.horizontal, 16)
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

    // MARK: - Leading capsule (search)

    @ViewBuilder
    private var searchControl: some View {
        if tab == .feed, !isSearchFieldActive {
            Button(action: onSearchTap) {
                searchPlaceholder
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Capsule())
            .accessibilityLabel("搜索")
        } else {
            searchField
                .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    private var searchPlaceholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)

            Text("搜索")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Image(systemName: "mic")
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Capsule())
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)

            TextField("搜索", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused(focus)
                .onSubmit(onSearchSubmit)

            Image(systemName: "mic")
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Trailing circles (date, plus)

    private var dateControl: some View {
        Button(action: onDateTap) {
            glassIcon("calendar.badge.clock")
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .matchedTransitionSource(id: AccessoryTransition.dateFilter, in: namespace)
        .accessibilityLabel("日期筛选")
        .accessibilityValue(dateLabel)
    }

    private var plusControl: some View {
        Button(action: onPlusTap) {
            glassIcon("plus")
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel("添加")
    }

    private func glassIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 21, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 24, height: 24)
            .padding(14)
            .contentShape(Circle())
    }
}
