import SwiftUI

struct FamilyBottomAccessory: View {
    @Environment(FamilyAccessoryState.self) private var accessory

    @Namespace private var namespace

    var body: some View {
        if accessory.isVisible {
            @Bindable var accessory = accessory

            HStack(spacing: 12) {
                Button {
                    accessory.isDateFilterPresented = true
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("日期筛选")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(accessory.dateLabel)
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
                .matchedTransitionSource(id: "dateAccessory", in: namespace)

                if accessory.pendingCount > 0 {
                    Button {
                        accessory.isPendingFilesPresented = true
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("待保存文件")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text("\(accessory.pendingCount) 条")
                                    .font(.subheadline.bold())
                            }
                        } icon: {
                            Image(systemName: "tray.and.arrow.down")
                                .foregroundStyle(.tint)
                        }
                    }
                    .buttonStyle(.plain)
                    .matchedTransitionSource(id: "pendingAccessory", in: namespace)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .sheet(isPresented: $accessory.isDateFilterPresented) {
                DateFilterPopover()
                    .navigationTransition(
                        .zoom(sourceID: "dateAccessory", in: namespace)
                    )
            }
            .sheet(isPresented: $accessory.isPendingFilesPresented) {
                if let familyURL = accessory.familyURL {
                    NavigationStack {
                        PendingFilesView(
                            familyURL: familyURL,
                            memberName: accessory.memberName
                        )
                    }
                    .navigationTransition(
                        .zoom(sourceID: "pendingAccessory", in: namespace)
                    )
                }
            }
        }
    }
}
