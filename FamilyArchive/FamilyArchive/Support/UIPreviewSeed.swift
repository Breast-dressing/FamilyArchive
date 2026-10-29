import Foundation
import SwiftData

#if DEBUG
@MainActor
enum UIPreviewSeed {
    static func seedIfNeeded(in context: ModelContext) {
        guard ProcessInfo.processInfo.arguments.contains("-UIPreviewSeed") else { return }
        let existing = (try? context.fetch(FetchDescriptor<Family>())) ?? []
        guard existing.isEmpty else { return }

        let profiles: [(name: String, honor: String, signature: String)] = [
            ("jaychou", "2031.5万+", "进家族私 ❤️ Jay Chou. 有缘之人可以逆转时光回到过去~~"),
            ("无与伦比", "1944.3万+", "无与伦比，为杰沉伦。"),
            ("Jay 真不错", "1832.6万+", "一路向北，等你下课。"),
            ("地表最强杰伦", "1658.6万+", "地表最强，继续前行。")
        ]

        for (index, profile) in profiles.enumerated() {
            let url = "https://i2.y.qq.com/?family_id=preview-\(index + 1)"
            let family = Family(
                url: url,
                name: profile.name,
                familyID: "preview-\(index + 1)",
                avatarURL: "",
                signature: profile.signature,
                honor: profile.honor,
                weekRank: "1",
                memberCountText: "30",
                pkWins: "54",
                sortOrder: index
            )
            context.insert(family)

            guard index == 0 else { continue }

            let names = [
                ("Tong ❤️", "V132", "NO.5203831", 832840),
                ("晓放的小企鹅", "V129", "NO.5200615", 772340),
                ("lollipop", "V108", "NO.5200791", 680760),
                ("Mega Jay", "V112", "NO.5201725", 648160),
                ("杰迷", "V120", "NO.5201888", 612340),
                ("Queen", "V101", "NO.5203344", 588900),
                ("JAY", "V98", "NO.5204422", 540210),
                ("七里香", "V95", "NO.5205533", 512300),
                ("晴天", "V89", "NO.5206644", 486700),
                ("夜曲", "V83", "NO.5207755", 462100)
            ]
            var members: [FamilyMember] = []
            for (memberIndex, item) in names.enumerated() {
                let member = FamilyMember(
                    memberID: "preview-member-\(memberIndex)",
                    name: item.0,
                    avatarURL: "",
                    familyURL: url,
                    medalLevel: item.1,
                    nameplate: item.2,
                    apiHonor: item.3
                )
                context.insert(member)
                members.append(member)
            }
            for extra in 0..<20 {
                let member = FamilyMember(
                    memberID: "preview-member-extra-\(extra)",
                    name: "成员 \(extra + 11)",
                    avatarURL: "",
                    familyURL: url,
                    medalLevel: "V\(70 + extra)",
                    nameplate: "NO.520\(8000 + extra)",
                    apiHonor: 300000 - extra * 5000
                )
                context.insert(member)
                members.append(member)
            }
            family.leaderMemberID = members.first?.memberID ?? ""
        }

        try? context.save()
    }

    /// Debug-only review route: the 动态 tab opens its 账号 sheet on launch so the
    /// NavigationBar-anchored zoom transition has a deterministic screenshot.
    static var wantsAccountsSheet: Bool {
        ProcessInfo.processInfo.arguments.contains("-UIPreviewAccounts")
    }

    /// Debug-only pending import used by the UI review route to exercise the
    /// "待保存文件" sheet without a real HAR selection.
    static func pendingOutcome() -> HARImportOutcome {
        let records = [
            ParsedHonorRecord(
                memberName: "Tong ❤️",
                taskName: "家族任务",
                honorValue: "+60荣誉值",
                time: "2026年10月24日 10:00"
            ),
            ParsedHonorRecord(
                memberName: "晓放的小企鹅",
                taskName: "家族任务",
                honorValue: "+40荣誉值",
                time: "2026年10月24日 10:05"
            ),
            ParsedHonorRecord(
                memberName: "lollipop",
                taskName: "家族任务",
                honorValue: "+30荣誉值",
                time: "2026年10月24日 10:10"
            )
        ]
        return HARImportOutcome(
            records: records,
            warnings: [],
            fileCount: 1,
            matchedResponseCount: 1,
            keptResponseCount: 1,
            fileNames: ["family-honor.har"]
        )
    }
}
#endif
