//
//  RootAccessoryViews.swift
//  FamilyArchive
//
//  Pure renderers for the TabView bottom accessory. None of these views owns
//  presentation state: RootView passes the single RootAccessoryState instance
//  and the shared transition namespace down.
//

import SwiftUI

struct FeedBottomAccessory: View {
    let state: RootAccessoryState
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 10) {
            Button {
                state.isDateFilterPresented = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("日期筛选")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(state.dateLabel)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: AccessoryTransition.dateFilter, in: namespace)

            Rectangle()
                .fill(Color(uiColor: .separator))
                .frame(width: 1, height: 26)

            Button {
                state.isFeedSearchPresented = true
            } label: {
                Label("搜索", systemImage: "magnifyingglass")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }
}

struct FamilyBottomAccessory: View {
    let state: RootAccessoryState
    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 12) {
            Button {
                state.isDateFilterPresented = true
            } label: {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("日期筛选")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(state.dateLabel)
                            .font(.subheadline.bold())
                            .lineLimit(1)
                    }
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.tint)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .matchedTransitionSource(id: AccessoryTransition.dateFilter, in: namespace)

            if state.pendingCount > 0 {
                Button {
                    state.isPendingFilesPresented = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("待保存文件")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(state.pendingCount) 条")
                                .font(.subheadline.bold())
                        }
                    } icon: {
                        Image(systemName: "tray.and.arrow.down")
                            .foregroundStyle(.tint)
                    }
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: AccessoryTransition.pendingFiles, in: namespace)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
