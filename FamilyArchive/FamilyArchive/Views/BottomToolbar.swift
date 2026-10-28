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
        HStack(spacing: 6) {
            if tab == .feed, !isSearchFieldActive {
                DateFilterAccessoryButton(
                    dateLabel: dateLabel,
                    namespace: namespace,
                    action: onDateTap
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                searchField
            }

            if tab == .feed {
                iconButton(
                    systemImage: "magnifyingglass",
                    label: "搜索",
                    action: onSearchTap
                )
            } else {
                iconButton(
                    systemImage: "calendar.badge.clock",
                    label: "日期筛选",
                    action: onDateTap
                )
                .matchedTransitionSource(
                    id: AccessoryTransition.dateFilter,
                    in: namespace
                )
            }

            iconButton(
                systemImage: "plus",
                label: "添加",
                action: onPlusTap
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
        .frame(maxWidth: .infinity)
    }

    private func iconButton(
        systemImage: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
