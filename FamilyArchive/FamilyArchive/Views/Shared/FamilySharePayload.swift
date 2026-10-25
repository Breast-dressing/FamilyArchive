import SwiftUI
import UIKit

struct FamilyShareMember: Identifiable, Hashable {
    let id: String
    let name: String
    let honor: Int

    var honorText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter.string(from: NSNumber(value: honor)) ?? "\(honor)"
    }
}

struct FamilySharePayload: Identifiable {
    let id = UUID()
    let familyName: String
    let familyURL: URL?
    let leaderName: String
    let period: String
    let members: [FamilyShareMember]
    let avatar: UIImage?

    var copyText: String {
        var lines = [
            "【\(familyName)】家族荣誉",
            "统计区间：\(period)",
            "族长：\(leaderName)",
            "成员（\(members.count)）："
        ]
        lines.append(contentsOf: members.map { "\($0.name)\t\($0.honorText)" })
        return lines.joined(separator: "\n")
    }
}

/// Image exported by the custom "图片" share action. Uses only system fonts
/// and system colors, with a two-column member grid.
struct FamilyHonorExportView: View {
    let payload: FamilySharePayload

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(payload.familyName.isEmpty ? "家族" : payload.familyName)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color(uiColor: .label))

                    Text("家族荣誉")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                }

                Spacer(minLength: 24)

                Text("FamilyArchive")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("统计区间：\(payload.period)")
                Text("族长：\(payload.leaderName)")
            }
            .font(.system(size: 16))
            .foregroundStyle(Color(uiColor: .secondaryLabel))

            Divider()

            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(payload.members) { member in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(member.name)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color(uiColor: .label))
                            .lineLimit(2)

                        Spacer(minLength: 8)

                        Text(member.honorText)
                            .font(.system(size: 17, weight: .bold).monospacedDigit())
                            .foregroundStyle(Color(uiColor: .label))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                }
            }

            Text("共 \(payload.members.count) 位成员 · 由 FamilyArchive 生成")
                .font(.system(size: 12))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(40)
        .frame(width: 900, alignment: .leading)
        .background(Color(uiColor: .systemBackground))
    }
}

@MainActor
enum FamilyHonorImageRenderer {
    static func image(for payload: FamilySharePayload) -> UIImage? {
        let renderer = ImageRenderer(content: FamilyHonorExportView(payload: payload))
        renderer.scale = 3
        return renderer.uiImage
    }
}
