import SwiftUI

struct DateFilterPopover: View {
    @Environment(DateFilterStore.self) private var dateFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var filter = dateFilter

        NavigationStack {
            Form {
                Section("选择日期") {
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
                } footer: {
                    Text("筛选 \(dateFilter.label)，即按自然日筛选记录。")
                }
            }
            .navigationTitle("日期筛选")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
