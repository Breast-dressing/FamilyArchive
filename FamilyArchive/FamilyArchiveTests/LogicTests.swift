import Foundation
import XCTest
@testable import FamilyArchive

final class HonorValueParserTests: XCTestCase {
    func testParsesPositiveHonorValue() {
        XCTAssertEqual(HonorValueParser.integer(from: "+60荣誉值"), 60)
        XCTAssertEqual(HonorValueParser.integer(from: "60"), 60)
    }

    func testParsesNegativeHonorValue() {
        XCTAssertEqual(HonorValueParser.integer(from: "-10荣誉值"), -10)
    }

    func testTotalsRecords() {
        let records = [
            HonorRecord(memberID: "m1", taskName: "a", honorValue: "+60荣誉值", time: "2026年07月26日 23:06", familyURL: "u"),
            HonorRecord(memberID: "m1", taskName: "b", honorValue: "+40荣誉值", time: "2026年07月27日 10:00", familyURL: "u"),
            HonorRecord(memberID: "m2", taskName: "c", honorValue: "+5荣誉值", time: "2026年07月27日 11:00", familyURL: "u")
        ]
        XCTAssertEqual(HonorValueParser.total(for: records), 105)
        XCTAssertEqual(HonorValueParser.total(for: records, memberID: "m1"), 100)
    }
}

final class AccountDraftTests: XCTestCase {
    func testValidDraftHasNoIssues() {
        let draft = AccountDraft(
            username: "alice",
            password: "secret",
            platform: .xiaohongshu,
            avatarData: Data([0x01]),
            platformLogoData: Data([0x02])
        )
        XCTAssertTrue(draft.isValid)
        XCTAssertTrue(draft.validationIssues.isEmpty)
    }

    func testMissingRequiredFieldsAreReported() {
        let draft = AccountDraft()
        let issues = draft.validationIssues
        XCTAssertFalse(draft.isValid)
        XCTAssertTrue(issues.contains("请输入账号"))
        XCTAssertTrue(issues.contains("请输入密码"))
        XCTAssertTrue(issues.contains("请选择头像"))
        XCTAssertTrue(issues.contains("请选择平台图标"))
    }
}

final class DateRangeFilterTests: XCTestCase {
    private var calendar: Calendar { Calendar.current }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testContainsInclusiveRange() {
        let filter = DateRangeFilter(
            start: date(2026, 7, 1),
            end: date(2026, 7, 31)
        )
        XCTAssertTrue(filter.contains(date(2026, 7, 1, hour: 0)))
        XCTAssertTrue(filter.contains(date(2026, 7, 31, hour: 23)))
        XCTAssertFalse(filter.contains(date(2026, 8, 1, hour: 0)))
    }

    func testMatchesChineseHARDate() {
        let filter = DateRangeFilter(
            start: date(2026, 7, 1),
            end: date(2026, 7, 31)
        )
        XCTAssertTrue(filter.matches(timeString: "2026年07月26日 23:06"))
        XCTAssertFalse(filter.matches(timeString: "2025年07月26日 23:06"))
    }

    func testUnknownDateIsKeptVisible() {
        let filter = DateRangeFilter(start: date(2026, 7, 1), end: date(2026, 7, 31))
        XCTAssertTrue(filter.matches(timeString: "not-a-date"))
    }

    func testParsesChineseDate() {
        let parsed = DateRangeFilter.date(from: "2026年07月26日 23:06")
        XCTAssertNotNil(parsed)
        let components = calendar.dateComponents([.year, .month, .day], from: parsed!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 26)
    }
}

final class FileSelectionValidatorTests: XCTestCase {
    func testClassifiesPhotosAndVideos() {
        XCTAssertTrue(FileSelectionValidator.isPhotoOrVideo(URL(fileURLWithPath: "/tmp/a.jpg")))
        XCTAssertTrue(FileSelectionValidator.isPhotoOrVideo(URL(fileURLWithPath: "/tmp/a.mov")))
        XCTAssertFalse(FileSelectionValidator.isPhotoOrVideo(URL(fileURLWithPath: "/tmp/a.txt")))
        XCTAssertFalse(FileSelectionValidator.isPhotoOrVideo(URL(fileURLWithPath: "/tmp/a.har")))
    }

    func testPartitionsSelection() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.jpg"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.mov")
        ]
        let result = FileSelectionValidator.partition(urls)
        XCTAssertEqual(result.accepted.map(\.lastPathComponent), ["b.txt"])
        XCTAssertEqual(result.rejected.map(\.lastPathComponent), ["a.jpg", "c.mov"])
    }
}

final class SocialPlatformTests: XCTestCase {
    func testOneTabPerPlatform() {
        let accounts = [
            Account(username: "a", platform: SocialPlatform.weibo.rawValue),
            Account(username: "b", platform: SocialPlatform.weibo.rawValue),
            Account(username: "c", platform: SocialPlatform.douyin.rawValue)
        ]
        XCTAssertEqual(
            SocialPlatform.uniquePlatforms(from: accounts),
            [SocialPlatform.weibo.rawValue, SocialPlatform.douyin.rawValue]
        )
    }

    func testNoAccountsMeansNoPlatformTabs() {
        XCTAssertEqual(SocialPlatform.uniquePlatforms(from: []), [])
    }
}

final class MemberNameResolverTests: XCTestCase {
    func testMatchesTrailingPunctuation() {
        XCTAssertTrue(MemberNameResolver.matches("姜黎非.", memberName: "姜黎非"))
    }

    func testDoesNotMatchDifferentNames() {
        XCTAssertFalse(MemberNameResolver.matches("Alice", memberName: "Bob"))
    }
}

final class PendingImportStoreTests: XCTestCase {
    func testSetAndClearPendingImport() {
        let store = PendingImportStore()
        let outcome = HARImportOutcome(
            records: [],
            warnings: [],
            fileCount: 0,
            matchedResponseCount: 0,
            keptResponseCount: 0,
            fileNames: []
        )

        store.setPending(outcome, for: "family")
        XCTAssertNotNil(store.pending(for: "family"))
        XCTAssertTrue(store.hasPending)

        store.clear(for: "family")
        XCTAssertNil(store.pending(for: "family"))
        XCTAssertFalse(store.hasPending)
    }
}

final class FamilyPageParserFieldTests: XCTestCase {
    func testParsesFamilySignatureStatsAndPKWins() {
        let json: [String: Any] = [
            "req_0": [
                "data": [
                    "Name": "jaychou",
                    "Announcement": "进家族私 ❤️ Jay Chou.",
                    "Avatar": "http://example.com/family.jpg",
                    "DetailItemList": [
                        ["Title": "2026.8万+", "Desc": "总荣誉值"],
                        ["Title": "1", "Desc": "周排名"],
                        ["Title": "30", "Desc": "成员"],
                        ["Title": "54", "Desc": "PK胜场"]
                    ]
                ]
            ]
        ]

        let info = FamilyPageParser.parseFamilyInfo(json)
        XCTAssertEqual(info?.name, "jaychou")
        XCTAssertEqual(info?.announcement, "进家族私 ❤️ Jay Chou.")
        XCTAssertEqual(info?.avatarURL, "https://example.com/family.jpg")
        XCTAssertEqual(info?.honor, "2026.8万+")
        XCTAssertEqual(info?.rank, "1")
        XCTAssertEqual(info?.members, "30")
        XCTAssertEqual(info?.pkWins, "54")
    }
}

final class QQMusicAPIMemberParsingTests: XCTestCase {
    func testParsesMedalNameplateAndAPIHonor() {
        let item: [String: Any] = [
            "ItemID": "5203831",
            "Title": "Tong",
            "Pic": "http://example.com/tong.jpg",
            "WearList": [
                [
                    "Title": "V132",
                    "Segment": [
                        "Contents": [
                            ["Content": "NO.5203831"]
                        ]
                    ]
                ] as [String: Any]
            ],
            "DescList": [
                ["Desc": "831040荣誉值"]
            ]
        ]

        let member = QQMusicAPI.parseMember(item)
        XCTAssertEqual(member?.memberID, "5203831")
        XCTAssertEqual(member?.name, "Tong")
        XCTAssertEqual(member?.avatarURL, "https://example.com/tong.jpg")
        XCTAssertEqual(member?.medalLevel, "V132")
        XCTAssertEqual(member?.nameplate, "NO.5203831")
        XCTAssertEqual(member?.apiHonor, 831040)
    }
}

final class MemberHonorDisplayTests: XCTestCase {
    private func record(_ value: String) -> HonorRecord {
        HonorRecord(
            memberID: "m1",
            taskName: "task",
            honorValue: value,
            time: "2026年10月24日 10:00",
            familyURL: "f"
        )
    }

    func testUsesFilteredRecordsWhenRangeHasRecords() {
        let filtered = [record("+300荣誉值")]
        let all = filtered + [record("+200荣誉值")]
        XCTAssertEqual(
            MemberHonorDisplay.total(
                apiHonor: 1000,
                filteredRecords: filtered,
                allRecords: all,
                hasAnyRecordInRange: true
            ),
            300
        )
    }

    func testShowsUnconsumedAPIHonorWhenRangeIsEmpty() {
        let all = [record("+200荣誉值")]
        XCTAssertEqual(
            MemberHonorDisplay.total(
                apiHonor: 1000,
                filteredRecords: [],
                allRecords: all,
                hasAnyRecordInRange: false
            ),
            800
        )
    }
}

final class DateFilterStoreTests: XCTestCase {
    func testDefaultRangeMatchesReferenceEightDayWindow() {
        let reference = Calendar.current.date(
            from: DateComponents(year: 2026, month: 10, day: 24, hour: 12)
        )!
        let store = DateFilterStore(referenceDate: reference)
        XCTAssertEqual(store.label, "2026年10月17日 至 2026年10月24日")
        XCTAssertEqual(store.accessoryLabel, "10/17 – 10/24")
    }

    func testDayKeyUsesReferenceFormat() {
        XCTAssertEqual(
            DateDisplay.dayKey(from: "2026年10月24日 10:00"),
            "2026年10月24日"
        )
    }
}

final class RootAccessoryStateTests: XCTestCase {
    func testLeavingFamilyRestoresSearchForm() {
        let state = RootAccessoryState()
        state.enterFamily(familyURL: "u", dateLabel: "2026年10月17日 至 2026年10月24日", pendingCount: 3)
        XCTAssertEqual(state.musicForm, .family)
        XCTAssertEqual(state.pendingCount, 3)

        state.leaveFamily()

        XCTAssertEqual(state.musicForm, .search)
        XCTAssertNil(state.familyURL)
        XCTAssertNil(state.memberName)
        XCTAssertEqual(state.pendingCount, 0)
    }

    func testEnteringMemberKeepsFamilyFormAndDateLabel() {
        let state = RootAccessoryState()
        state.enterFamily(familyURL: "u", dateLabel: "range", pendingCount: 1)
        state.enterMember(
            name: "Tong",
            familyURL: "u",
            dateLabel: "range",
            pendingCount: 2
        )

        XCTAssertEqual(state.musicForm, .family)
        XCTAssertEqual(state.memberName, "Tong")
        XCTAssertEqual(state.dateLabel, "range")
        XCTAssertEqual(state.pendingCount, 2)
    }

    func testReturningToFamilyClearsMemberButKeepsDateForm() {
        let state = RootAccessoryState()
        state.enterMember(
            name: "Tong",
            familyURL: "u",
            dateLabel: "range",
            pendingCount: 2
        )
        state.enterFamily(familyURL: "u", dateLabel: "range", pendingCount: 2)

        XCTAssertEqual(state.musicForm, .family)
        XCTAssertNil(state.memberName)
        XCTAssertEqual(state.dateLabel, "range")
    }
}


final class FamilySharePayloadTests: XCTestCase {
    private func payload() -> FamilySharePayload {
        FamilySharePayload(
            familyName: "jaychou",
            familyURL: URL(string: "https://i2.y.qq.com/?family_id=preview-1"),
            leaderName: "Tong",
            period: "2026年10月18日 至 2026年10月25日",
            members: [
                FamilyShareMember(id: "m1", name: "Tong", honor: 832840),
                FamilyShareMember(id: "m2", name: "lollipop", honor: 680760)
            ],
            avatar: nil
        )
    }

    func testCopyTextContainsPeriodLeaderAndEveryMember() {
        let text = payload().copyText
        XCTAssertTrue(text.contains("jaychou"))
        XCTAssertTrue(text.contains("2026年10月18日 至 2026年10月25日"))
        XCTAssertTrue(text.contains("族长：Tong"))
        XCTAssertTrue(text.contains("Tong\t832,840"))
        XCTAssertTrue(text.contains("lollipop\t680,760"))
    }

    @MainActor
    func testHonorImageRendersAtExportWidth() {
        let image = FamilyHonorImageRenderer.image(for: payload())
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.scale, 3)
        XCTAssertGreaterThan(image?.size.width ?? 0, 0)
    }
}


final class BadgeSkinServiceTests: XCTestCase {
    func testParsesSkinSSR() {
        let json = """
        {"code":0,"data":{"SkinInfo":{"ID":"3069960-100","Name":"星夜","UnlockedTs":1700000000,"UnlockedUserCnt":12,"LevelList":[{"Pic":"https://example.com/skin.png","State":2,"BGColor":"#ffffff","LevelUnlockGuide":{"TaskList":[{"Title":"完成签到"}]}}]}}}
        """
        let escaped = json.replacingOccurrences(of: "\"", with: "\\\"")
        let html = "window.__ssrFirstPageData__ = \"\(escaped)\";"

        let skin = BadgeSkinService.parse(html: html, sequence: 100)
        XCTAssertEqual(skin?.name, "星夜")
        XCTAssertEqual(skin?.isUnlocked, true)
        XCTAssertEqual(skin?.userCount, 12)
        XCTAssertEqual(skin?.unlockTask, "完成签到")
        XCTAssertEqual(skin?.imageURL, "https://example.com/skin.png")
    }
}

final class MedalHallServiceTests: XCTestCase {
    func testParsesModuleAndMedals() {
        let module: [String: Any] = [
            "ModuleID": 7,
            "ModuleName": "默认勋章",
            "Style": ["HasNext": true],
            "MedalList": [
                [
                    "MedalID": "medal-1",
                    "Name": "闪耀",
                    "PicURL": "https://example.com/medal.png",
                    "Level": 3,
                    "CreateTime": "2026-10-01"
                ],
                [
                    "MedalID": "medal-2",
                    "Name": "未获得",
                    "PicURL": "",
                    "Level": 1
                ]
            ]
        ]

        let modules = MedalHallService.parseModules([module])
        XCTAssertEqual(modules.count, 1)
        XCTAssertEqual(modules.first?.name, "默认勋章")
        XCTAssertEqual(modules.first?.medals.count, 2)
        XCTAssertEqual(modules.first?.medals.first?.isObtained, true)
        XCTAssertEqual(modules.first?.medals.last?.isObtained, false)
    }
}

final class LyricCardServiceTests: XCTestCase {
    func testParsesHARCardsAndSerials() throws {
        let cards: [[String: Any]] = [
            [
                "ID": "card-1",
                "Rarity": 6,
                "FgPic": "http://example.com/front.png",
                "Num": 2,
                "CardBackInfo": [
                    "SongName": "七里香",
                    "SingerName": "周杰伦",
                    "Pic": "http://example.com/back.png"
                ],
                "CardMaterialInfo": [
                    "CardMaterials": [
                        ["MaterialName": "星光", "IsUnlock": true, "MaterialPic": ""]
                    ]
                ]
            ]
        ]
        let ssr: [String: Any] = ["allCardList": ["Cards": cards]]
        let ssrData = try JSONSerialization.data(withJSONObject: ssr)
        let ssrString = String(data: ssrData, encoding: .utf8)!
        let escaped = ssrString.replacingOccurrences(of: "\"", with: "\\\"")
        let html = "window.__ssrFirstPageData__ = \"\(escaped)\";"

        let requestPost = """
        {"req_0":{"param":{"IDs":["card-1"]}}}
        """
        let responseJSON = """
        {"req_0":{"data":{"Card":{"ID":"card-1","SerialNumList":["A001","A002"]}}}}
        """

        let har: [String: Any] = [
            "log": [
                "entries": [
                    [
                        "request": ["url": "https://y.qq.com/singer_cards_collection.html"],
                        "response": ["content": ["text": html]]
                    ],
                    [
                        "request": [
                            "url": "https://u6.y.qq.com/cgi-bin/musics.fcg?_webcgikey=GetCardInfoByIDs",
                            "postData": ["text": requestPost]
                        ],
                        "response": ["content": ["text": responseJSON]]
                    ]
                ]
            ]
        ]

        let data = try JSONSerialization.data(withJSONObject: har)
        let parsed = try LyricCardService.parseHAR(data: data)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.songName, "七里香")
        XCTAssertEqual(parsed.first?.rarity, "SSR")
        XCTAssertEqual(parsed.first?.serials, ["A001", "A002"])
        XCTAssertEqual(parsed.first?.imageURL, "https://example.com/front.png")
    }
}

final class BottomToolbarLayoutTests: XCTestCase {
    func testControlOrderIsLockedToSearchDatePlus() {
        XCTAssertEqual(BottomToolbarLayout.controls, [.search, .date, .plus])
    }

    func testControlOrderNeverChangesWithTab() {
        for tab in RootTab.allCases {
            XCTAssertEqual(
                BottomToolbarLayout.controls(for: tab),
                [.search, .date, .plus],
                "\(tab.title) 的工具栏顺序被改动"
            )
        }
    }
}

final class RootTabTests: XCTestCase {
    func testMainTabOrderIsFeedVideoMusicMore() {
        XCTAssertEqual(RootTab.allCases, [.feed, .video, .music, .more])
    }

    func testMoreTabMetadataStaysLast() {
        XCTAssertEqual(RootTab.more.title, "更多")
        XCTAssertEqual(RootTab.more.systemImage, "ellipsis")
        XCTAssertEqual(RootTab.allCases.last, .more)
    }
}

final class MedalHallURLTests: XCTestCase {
    func testFixedURLMatchesRequiredMedalURL() {
        XCTAssertEqual(
            MedalHallService.fixedURLString,
            "https://i2.y.qq.com/n3/client/pages/medal_collection_new/index.html?_hidehd=1&_fontscale=1&_miniplayer=1&enc_uin=oKEkoiCFoKCAoz**&entry=profile&_button=1"
        )
        XCTAssertEqual(MedalHallService.fixedEncUin, "oKEkoiCFoKCAoz**")
    }

    func testNormalizedURLReplacesExistingEncUin() {
        let source = "https://i2.y.qq.com/n3/client/pages/medal_collection_new/index.html?_hidehd=1&_fontscale=1&_miniplayer=1&enc_uin=someoneElse**&entry=profile&_button=1"
        let normalized = MedalHallService.normalizedURLString(source)
        XCTAssertTrue(normalized.contains("enc_uin=oKEkoiCFoKCAoz**"))
        XCTAssertFalse(normalized.contains("someoneElse"))
        XCTAssertTrue(normalized.contains("entry=profile"))
        XCTAssertTrue(normalized.contains("_button=1"))
    }

    func testNormalizedURLAddsEncUinWhenMissing() {
        let normalized = MedalHallService.normalizedURLString(
            "https://i2.y.qq.com/n3/client/pages/medal_collection_new/index.html?entry=profile"
        )
        XCTAssertTrue(normalized.contains("enc_uin=oKEkoiCFoKCAoz**"))
    }
}

final class BadgeSkinRangeTests: XCTestCase {
    func testQuerySequencesOrdersAndCapsAtFiveHundred() {
        let sequences = BadgeSkinService.querySequences(start: 300, end: 100)
        XCTAssertEqual(sequences.first, 100)
        XCTAssertEqual(sequences.last, 300)
        XCTAssertEqual(sequences.count, 201)
    }

    func testQuerySequencesClampsToFiveHundredEntries() {
        let sequences = BadgeSkinService.querySequences(start: 1, end: 900)
        XCTAssertEqual(sequences.count, 500)
        XCTAssertEqual(sequences.first, 1)
        XCTAssertEqual(sequences.last, 500)
    }

    func testQuerySequencesClampsToPositiveNumbers() {
        let sequences = BadgeSkinService.querySequences(start: -20, end: 5)
        XCTAssertEqual(sequences.first, 1)
        XCTAssertEqual(sequences.last, 5)
    }
}

final class MusicQueryStoreTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "MusicQueryStoreTests-\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    func testSavedRecordsPersistAndFilterByKind() {
        let defaults = makeDefaults()
        let store = MusicQueryStore(defaults: defaults)
        store.save(
            kind: MusicQueryRecord.badgeKind,
            accountName: "jay",
            encUin: "jay**",
            summary: "皮肤 3 个"
        )
        store.save(
            kind: MusicQueryRecord.medalKind,
            accountName: "jay",
            encUin: MedalHallService.fixedEncUin,
            summary: "分类 2 个"
        )

        XCTAssertEqual(store.records(for: MusicQueryRecord.badgeKind).count, 1)
        XCTAssertEqual(store.records(for: MusicQueryRecord.medalKind).count, 1)
        XCTAssertEqual(store.records(for: MusicQueryRecord.badgeKind).first?.summary, "皮肤 3 个")

        let reloaded = MusicQueryStore(defaults: defaults)
        XCTAssertEqual(reloaded.records.count, 2)
        XCTAssertEqual(reloaded.records.first?.kind, MusicQueryRecord.medalKind)
    }
}

/// Every tab presents 账号 from its own NavigationBar button, and the zoom
/// transition anchors on the matching `matchedTransitionSource`. A duplicated id
/// would anchor on a button that is not on screen, and an id that collides with
/// the bottom accessory would anchor on the wrong chrome entirely.
final class AccountsTransitionSourceTests: XCTestCase {
    func testSourceIDsAreStablePerScope() {
        XCTAssertEqual(AccountsTransitionSource.sourceID(for: .feed), "accounts.feed")
        XCTAssertEqual(AccountsTransitionSource.sourceID(for: .video), "accounts.video")
        XCTAssertEqual(AccountsTransitionSource.sourceID(for: .music), "accounts.music")
    }

    func testEveryScopeHasExactlyOneSourceID() {
        let ids = AccountsTransitionSource.allIDs
        XCTAssertEqual(ids.count, AccountScope.allCases.count)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testSourceIDsNeverCollideWithAccessoryTransitions() {
        let accessoryIDs: Set<String> = [
            AccessoryTransition.dateFilter,
            AccessoryTransition.pendingFiles,
            AccessoryTransition.plus
        ]
        XCTAssertTrue(Set(AccountsTransitionSource.allIDs).isDisjoint(with: accessoryIDs))
    }
}
