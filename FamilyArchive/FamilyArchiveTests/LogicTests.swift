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
