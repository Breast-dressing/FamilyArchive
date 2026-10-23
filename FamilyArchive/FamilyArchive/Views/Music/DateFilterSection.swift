import Foundation
import SwiftUI

struct DateFilterSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    let totalCount: Int

    @State private var isExpanded = true

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                DatePicker("开始日期", selection: $startDate, displayedComponents: .date)
                DatePicker("结束日期", selection: $endDate, displayedComponents: .date)
            } label: {
                HStack {
                    Label("日期筛选", systemImage: "calendar")
                    Spacer()
                    Text("\(totalCount) 条记录")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .animation(.snappy, value: isExpanded)
    }
}
