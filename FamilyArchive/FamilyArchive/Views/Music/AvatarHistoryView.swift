import SwiftData
import SwiftUI

struct AvatarHistoryView: View {
    let family: Family

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FamilyAvatarHistory.startDate, order: .reverse)
    private var histories: [FamilyAvatarHistory]

    private var familyHistories: [FamilyAvatarHistory] {
        histories.filter { $0.familyURL == family.url }
    }

    var body: some View {
        List {
            Section("历史头像") {
                if familyHistories.isEmpty {
                    Text("暂无头像历史")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(familyHistories) { history in
                        HStack(spacing: 12) {
                            RemoteAvatarView(
                                urlString: history.avatarURL,
                                systemImage: "person.3.fill",
                                size: 64
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(dateRange(for: history))
                                    .font(.subheadline.bold())
                                if history.endDate == nil {
                                    Text("当前使用")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
        .navigationTitle("更改头像")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完成") { dismiss() }
            }
        }
    }

    private func dateRange(for history: FamilyAvatarHistory) -> String {
        let start = DateDisplay.day(history.startDate)
        if let endDate = history.endDate {
            return "\(start) 至 \(DateDisplay.day(endDate))"
        }
        return "\(start) 至今"
    }
}
