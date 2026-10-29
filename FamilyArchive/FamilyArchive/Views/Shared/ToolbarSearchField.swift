//
//  ToolbarSearchField.swift
//  FamilyArchive
//
//  Native search shell for the floating toolbar: system TextField configured
//  for search plus the system clear (×) control. Its height is locked to the
//  same 44pt hit area as the NavigationBar's circular buttons.
//

import SwiftUI

struct ToolbarSearchField: View {
    @Binding var text: String
    var focus: FocusState<Bool>.Binding
    var onSubmit: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.secondary)

            TextField("搜索", text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused(focus)
                .onSubmit {
                    focus.wrappedValue = false
                    onSubmit()
                }

            if focus.wrappedValue || !text.isEmpty {
                Button {
                    text = ""
                    focus.wrappedValue = false
                    onSubmit()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索")
                .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: BottomToolbarLayout.controlSize)
        .animation(.snappy, value: focus.wrappedValue)
        .animation(.snappy, value: text.isEmpty)
    }
}
