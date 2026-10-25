import SwiftUI

/// App Store style, fully opaque date filter sheet. No liquid glass materials
/// are used; the background is the adaptive `systemBackground` color.
struct DateFilterPopover: View {
    @Environment(DateFilterStore.self) private var dateFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var filter = dateFilter

        VStack(spacing: 0) {
            AppStoreSheetHeader(title: "日期筛选") {
                dismiss()
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 0) {
                    DatePicker(
                        "起始日期",
                        selection: $filter.startDate,
                        displayedComponents: .date
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()
                        .padding(.leading, 16)

                    DatePicker(
                        "结束日期",
                        selection: $filter.endDate,
                        displayedComponents: .date
                    )
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(
                    Color(uiColor: .secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )

                Text("筛选 \(dateFilter.label)，即按自然日筛选记录。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("完成") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .presentationSizing(.fitted)
        .presentationBackground(Color(uiColor: .systemBackground))
    }
}
