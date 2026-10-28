import SwiftUI

/// Custom bottom toolbar that replaces the previous detached "＋" tab and the
/// `tabViewBottomAccessory`. Three layouts are driven by the selected tab.
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
                leftContent

                Spacer(minLength: 4)

                rightButtons
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var leftContent: some View {
        if tab == .feed, !isSearchFieldActive {
            DateFilterAccessoryButton(
                dateLabel: dateLabel,
                namespace: namespace,
                action: onDateTap
            )
            .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            searchField
                .glassEffect(.regular.interactive(), in: Capsule())
        }
    }

    @ViewBuilder
    private var rightButtons: some View {
        if tab == .feed, !isSearchFieldActive {
            circleButton(
                systemImage: "magnifyingglass",
                label: "搜索",
                action: onSearchTap
            )
        } else {
            circleButton(
                systemImage: "calendar.badge.clock",
                label: "日期筛选",
                action: onDateTap
            )
            .matchedTransitionSource(
                id: AccessoryTransition.dateFilter,
                in: namespace
            )
        }

        circleButton(
            systemImage: "plus",
            label: "添加",
            action: onPlusTap
        )
    }

    private func circleButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 24)
                .padding(15)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Circle())
        .accessibilityLabel(label)
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
        .frame(maxWidth: .infinity)
    }
}
