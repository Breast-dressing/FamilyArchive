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
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text("日期筛选")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(dateLabel)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: AccessoryTransition.dateFilter, in: namespace)
    }
}
