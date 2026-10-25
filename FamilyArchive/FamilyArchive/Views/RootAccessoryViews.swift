//
//  RootAccessoryViews.swift
//  FamilyArchive
//
//  Pure renderers for the TabView bottom accessory. RootView owns all
//  presentation state; these views only render the state they are given.
//

import SwiftUI

/// The single date-filter accessory used by both the Feed tab and the family
/// page. Keeping one component guarantees identical structure, icon size and
/// padding in both places.
struct DateFilterAccessoryButton: View {
    let dateLabel: String
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.all, 10)

                VStack(alignment: .leading, spacing: 1) {
                    Text("日期筛选")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(dateLabel)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: AccessoryTransition.dateFilter, in: namespace)
    }
}

/// Pending files is its own mutually exclusive accessory form; it is never
/// shown together with the date filter.
struct PendingFilesAccessoryButton: View {
    let count: Int
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.all, 10)

                VStack(alignment: .leading, spacing: 1) {
                    Text("待保存文件")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(count) 条")
                        .font(.subheadline.bold())
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: AccessoryTransition.pendingFiles, in: namespace)
    }
}

/// Feed tab: the shared date filter on the leading edge, a single search icon
/// on the trailing edge. Both icons use the same 20pt symbol and 10pt padding.
struct FeedBottomAccessory: View {
    let dateLabel: String
    let namespace: Namespace.ID
    let onDateFilter: () -> Void
    let onSearch: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            DateFilterAccessoryButton(
                dateLabel: dateLabel,
                namespace: namespace,
                action: onDateFilter
            )

            Spacer(minLength: 8)

            Button(action: onSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .padding(.all, 10)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity)
    }
}

struct SearchBottomAccessory: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}
