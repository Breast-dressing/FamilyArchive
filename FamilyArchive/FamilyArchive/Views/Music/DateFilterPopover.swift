import SwiftUI

/// Native sheet content for the date filter. The close control is a real
/// toolbar item (never a hand-positioned overlay), and the sheet background is
/// the adaptive opaque `systemBackground` color.
struct DateFilterPopover: View {
    @Environment(DateFilterStore.self) private var dateFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var filter = dateFilter

        NavigationStack {
            Form {
                Section {
                    DatePicker(
                        "起始日期",
                        selection: $filter.startDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        "结束日期",
                        selection: $filter.endDate,
                        displayedComponents: .date
                    )
                } header: {
                    Text("选择日期")
                } footer: {
                    Text("筛选 \(dateFilter.label)，即按自然日筛选记录。")
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("日期筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭")
                }
            }
        }
        .environment(\.locale, Locale(identifier: "zh_CN"))
        .presentationBackground(Color(uiColor: .systemBackground))
    }
}
