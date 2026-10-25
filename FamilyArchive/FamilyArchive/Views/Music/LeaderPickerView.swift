import SwiftData
import SwiftUI

struct LeaderPickerView: View {
    let family: Family

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var members: [FamilyMember]

    @State private var selectedMemberID: String

    init(family: Family) {
        self.family = family
        _selectedMemberID = State(initialValue: family.leaderMemberID)
    }

    private var familyMembers: [FamilyMember] {
        members
            .filter { $0.familyURL == family.url }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("选择族长") {
                    if familyMembers.isEmpty {
                        Text("暂无成员")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(familyMembers) { member in
                            Button {
                                selectedMemberID = member.memberID
                            } label: {
                                HStack(spacing: 12) {
                                    RemoteAvatarView(
                                        urlString: member.avatarURL,
                                        systemImage: "person.crop.circle.fill",
                                        size: 40
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(member.name)
                                            .foregroundStyle(.primary)
                                        if !member.medalLevel.isEmpty {
                                            Text(member.medalLevel)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedMemberID == member.memberID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: [.top, .bottom])
            .navigationTitle("添加族长")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        family.leaderMemberID = selectedMemberID
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(selectedMemberID.isEmpty)
                }
            }
        }
    }
}
