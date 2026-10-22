import Foundation
import XCTest
@testable import FamilyArchive

final class FamilyArchiveTests: XCTestCase {
    func testExtractsFamilyIDFromQuery() {
        let url = URL(string: "https://i2.y.qq.com/?family_id=abc_123")!
        XCTAssertEqual(FamilyURLParser.extractFamilyID(from: url), "abc_123")
    }

    func testExtractsFamilyIDFromPath() {
        let url = URL(string: "https://i2.y.qq.com/family/98765")!
        XCTAssertEqual(FamilyURLParser.extractFamilyID(from: url), "98765")
    }

    func testParsesHonorRecordFields() {
        let raw = #"{"Title":"看视频得乐迷值 @姜黎非.","Date":"2026年07月26日 23:06","Value":"+60荣誉值"}"#
        let record = HARImportService.parseRecord(raw)

        XCTAssertEqual(record?.taskName, "看视频得乐迷值")
        XCTAssertEqual(record?.memberName, "姜黎非")
        XCTAssertEqual(record?.time, "2026年07月26日 23:06")
        XCTAssertEqual(record?.honorValue, "+60荣誉值")
    }
}
