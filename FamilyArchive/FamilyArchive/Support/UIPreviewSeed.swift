import Foundation
import SwiftData
import UIKit

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

        seedFeedPosts(in: context)
        seedVideoShows(in: context)
        seedMusicLibrary(in: context)

        try? context.save()
    }

    /// 预览用动态：1 / 4 / 9 张图各一条，覆盖九宫格的三种列数。
    private static func seedFeedPosts(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<FeedPost>())) ?? []
        guard existing.isEmpty else { return }

        let specs: [(count: Int, platform: String, title: String, group: FeedOwnerGroup, author: String)] = [
            (1, SocialPlatform.weibo.rawValue, "今日份的宝宝", .baby, "宝宝"),
            (4, SocialPlatform.xiaohongshu.rawValue, "小室拍摄花絮", .studio, "小室"),
            (9, SocialPlatform.douyin.rawValue, "甲方爸爸的物料", .client, "甲方")
        ]

        for (index, spec) in specs.enumerated() {
            let media = (0..<spec.count).compactMap { previewImageData(seed: index * 9 + $0) }
            let post = FeedPost(
                platform: spec.platform,
                caption: spec.title,
                mediaData: media,
                mediaIsVideo: media.map { _ in false },
                createdAt: Date().addingTimeInterval(Double(-index) * 86_400),
                ownerGroup: spec.group.rawValue,
                author: spec.author,
                title: spec.title
            )
            context.insert(post)
        }
    }

    /// 预览用影视：覆盖 剧集 / 电影 / 综艺 / 花絮 与 待播 / 待拍。
    private static func seedVideoShows(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<VideoShow>())) ?? []
        guard existing.isEmpty else { return }

        let specs: [(title: String, category: VideoCategory, status: VideoStatus, platform: SocialPlatform)] = [
            ("未命名长剧", .episode, .pending, .bilibili),
            ("夏日电影", .movie, .shooting, .weibo),
            ("周末综艺", .variety, .pending, .douyin),
            ("片场花絮", .behind, .shooting, .xiaohongshu)
        ]

        for (index, spec) in specs.enumerated() {
            let show = VideoShow(
                platform: spec.platform.rawValue,
                title: spec.title,
                synopsis: "预览用简介",
                cast: "预览演员",
                coverData: previewImageData(seed: index + 20),
                createdAt: Date().addingTimeInterval(Double(-index) * 86_400),
                category: spec.category.rawValue,
                status: spec.status.rawValue
            )
            context.insert(show)
        }
    }

    /// 预览用音乐库：3 个自建歌单、2 个合集、3 首歌。
    private static func seedMusicLibrary(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Playlist>())) ?? []
        guard existing.isEmpty else { return }

        var playlistIDs: [UUID] = []
        for (index, name) in ["通勤", "睡前", "现场"].enumerated() {
            let playlist = Playlist(
                name: name,
                coverData: previewImageData(seed: 30 + index),
                sortOrder: index
            )
            context.insert(playlist)
            playlistIDs.append(playlist.id)
        }

        for (index, name) in ["独唱合集", "清唱合集"].enumerated() {
            let collection = SongCollection(
                name: name,
                coverData: previewImageData(seed: 40 + index),
                sortOrder: index
            )
            context.insert(collection)
        }

        for (index, title) in ["七里香", "晴天", "稻香"].enumerated() {
            let song = Song(
                title: title,
                artist: "Jay",
                category: SongCategory.solo.rawValue,
                playlistID: playlistIDs[index % playlistIDs.count],
                sortOrder: index
            )
            context.insert(song)
        }
    }

    private static func previewImageData(seed: Int) -> Data? {
        let size = CGSize(width: 180, height: 180)
        let colors: [UIColor] = [.systemPink, .systemBlue, .systemTeal, .systemIndigo, .systemOrange]
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            colors[seed % colors.count].withAlphaComponent(0.45).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let text = "\(seed + 1)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 48, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = text.size(withAttributes: attributes)
            text.draw(
                at: CGPoint(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2
                ),
                withAttributes: attributes
            )
        }
        return image.jpegData(compressionQuality: 0.7)
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
