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
