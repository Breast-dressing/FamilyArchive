//
//  HARImportService.swift
//  FamilyArchive
//
//  Strict implementation of the HAR pipeline described in the specification:
//
//  1. Keep requests whose URL contains
//     "https://u6.y.qq.com/cgi-bin/musics.fcg?_webcgikey=GetFamilyHonorRecord&_=".
//  2. Extract the text between the first "[" and the last "]".
//  3. Deduplicate against the previous four *filtered* responses (a sliding
//     window, not a fixed baseline), across all selected files treated as one
//     ordered sequence: file selection order first, HAR entry order second.
//  4. Extract every "{...}" record segment from each retained response.
//  5. Parse taskName / memberName / time / honorValue.
//
//  File I/O and parsing run off the main thread.
//

import Foundation

struct ParsedHonorRecord: Sendable, Hashable {
    let memberName: String
    let taskName: String
    let honorValue: String
    let time: String
}

struct HARImportOutcome: Sendable {
    let records: [ParsedHonorRecord]
    let warnings: [String]
    let fileCount: Int
    let matchedResponseCount: Int
    let keptResponseCount: Int
    let fileNames: [String]
}

enum HARImportService {
    /// Exact string required by the specification.
    static let targetURLFragment = "https://u6.y.qq.com/cgi-bin/musics.fcg?_webcgikey=GetFamilyHonorRecord&_="

    /// Number of previous filtered responses the current one is compared with.
    private static let deduplicationWindow = 4

    private static let recordRegex = try? NSRegularExpression(pattern: "\\{[^{}]*\\}")
    private static let titleRegex = try? NSRegularExpression(pattern: "\"Title\"\\s*:\\s*\"([^\"]*)\"")
    private static let dateRegex = try? NSRegularExpression(pattern: "\"Date\"\\s*:\\s*\"([^\"]*)\"")
    private static let valueRegex = try? NSRegularExpression(pattern: "\"Value\"\\s*:\\s*\"([^\"]*)\"")

    static func parse(urls: [URL]) async -> HARImportOutcome {
        await Task.detached(priority: .userInitiated) {
            parseSynchronously(urls: urls)
        }.value
    }

    // MARK: - Pipeline

    private static func parseSynchronously(urls: [URL]) -> HARImportOutcome {
        var filteredTexts: [String] = []
        var keptTexts: [String] = []
        var warnings: [String] = []
        var fileCount = 0
        var fileNames: [String] = []

        for url in urls {
            let displayName = url.lastPathComponent.isEmpty ? url.absoluteString : url.lastPathComponent
            fileNames.append(displayName)

            let data: Data
            do {
                data = try Data(contentsOf: url, options: [.mappedIfSafe])
            } catch {
                appendWarning("\(displayName)：无法读取（\(error.localizedDescription)）。", to: &warnings)
                continue
            }

            guard let object = try? JSONSerialization.jsonObject(with: data),
                  let root = object as? [String: Any],
                  let log = root["log"] as? [String: Any],
                  let entries = log["entries"] as? [[String: Any]] else {
                appendWarning("\(displayName)：不是有效的记录文件。", to: &warnings)
                continue
            }

            fileCount += 1
            var matchedInFile = 0

            for entry in entries {
                guard let request = entry["request"] as? [String: Any] else { continue }
                let requestURL = JSONSupport.string(request["url"])
                guard requestURL.contains(targetURLFragment) else { continue }

                guard let response = entry["response"] as? [String: Any],
                      let content = response["content"] as? [String: Any] else {
                    continue
                }
                let responseText = decodeContentText(content)
                guard !responseText.isEmpty,
                      let arrayText = extractArrayText(from: responseText) else {
                    continue
                }

                matchedInFile += 1

                // Step 3: compare against the previous four filtered responses,
                // including ones that were themselves discarded.
                let precedingCount = min(deduplicationWindow, filteredTexts.count)
                let windowStart = filteredTexts.count - precedingCount
                let window = filteredTexts[windowStart..<filteredTexts.count]
                if !window.contains(arrayText) {
                    keptTexts.append(arrayText)
                }
                filteredTexts.append(arrayText)
            }

            if matchedInFile == 0 {
                appendWarning("\(displayName)：未找到家族荣誉记录响应。", to: &warnings)
            }
        }

        var records: [ParsedHonorRecord] = []
        var skippedRecordCount = 0
        var skippedSamples: [String] = []

        for arrayText in keptTexts {
            for recordText in extractRecordSegments(from: arrayText) {
                if let record = parseRecord(recordText) {
                    records.append(record)
                } else {
                    skippedRecordCount += 1
                    if skippedSamples.count < 3 {
                        skippedSamples.append(sampleTitle(from: recordText))
                    }
                }
            }
        }

        if skippedRecordCount > 0 {
            var warning = "\(skippedRecordCount) 条记录因标题中没有可解析的成员名而被跳过。"
            let samples = skippedSamples.filter { !$0.isEmpty }
            if !samples.isEmpty {
                warning += " 示例：" + samples.joined(separator: " / ")
            }
            appendWarning(warning, to: &warnings)
        }

        return HARImportOutcome(
            records: records,
            warnings: warnings,
            fileCount: fileCount,
            matchedResponseCount: filteredTexts.count,
            keptResponseCount: keptTexts.count,
            fileNames: fileNames
        )
    }

    // MARK: - Response text

    /// Port of `_decode_response_text` (HAR responses are frequently base64).
    static func decodeContentText(_ content: [String: Any]) -> String {
        let rawText = JSONSupport.string(content["text"])
        guard !rawText.isEmpty else { return "" }

        let encoding = JSONSupport.string(content["encoding"]).lowercased()
        guard encoding == "base64" else { return rawText }

        guard let data = Data(base64Encoded: rawText, options: [.ignoreUnknownCharacters]) else {
            return ""
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    /// Step 2: the text between the first "[" and the last "]".
    static func extractArrayText(from text: String) -> String? {
        guard let open = text.firstIndex(of: "["),
              let close = text.lastIndex(of: "]"),
              open < close else {
            return nil
        }
        return String(text[text.index(after: open)..<close])
    }

    // MARK: - Records

    static func extractRecordSegments(from text: String) -> [String] {
        guard let regex = recordRegex else { return [] }
        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        return regex.matches(in: text, options: [], range: range).map {
            nsText.substring(with: $0.range)
        }
    }

    /// Step 5: parse one `{...}` record.
    ///
    /// * taskName   = Title before "@", trimmed
    /// * memberName = Title after "@", trimmed, trailing punctuation removed
    /// * time       = Date value
    /// * honorValue = Value value (including e.g. "+60荣誉值")
    static func parseRecord(_ text: String) -> ParsedHonorRecord? {
        guard let title = value(for: titleRegex, in: text) else { return nil }
        guard let atIndex = title.firstIndex(of: "@") else { return nil }

        let taskName = String(title[title.startIndex..<atIndex])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var memberName = String(title[title.index(after: atIndex)...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        memberName = removingTrailingPunctuation(from: memberName)
        guard !memberName.isEmpty else { return nil }

        let time = value(for: dateRegex, in: text) ?? ""
        let honorValue = value(for: valueRegex, in: text) ?? ""

        return ParsedHonorRecord(
            memberName: memberName,
            taskName: taskName,
            honorValue: honorValue,
            time: time
        )
    }

    private static func value(for regex: NSRegularExpression?, in text: String) -> String? {
        guard let regex else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }

    static func removingTrailingPunctuation(from value: String) -> String {
        var result = value
        var didTrim = true
        while didTrim {
            didTrim = false
            if let last = result.last,
               last.unicodeScalars.allSatisfy({
                   CharacterSet.punctuationCharacters.contains($0)
                       || CharacterSet.whitespacesAndNewlines.contains($0)
               }) {
                result.removeLast()
                didTrim = true
            }
        }
        return result
    }

    private static func sampleTitle(from recordText: String) -> String {
        let title = value(for: titleRegex, in: recordText) ?? ""
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 40 {
            return String(trimmed.prefix(40)) + "…"
        }
        return trimmed
    }

    // MARK: - Helpers

    private static func appendWarning(_ warning: String, to warnings: inout [String]) {
        guard warnings.count < 12 else { return }
        warnings.append(warning)
    }
}
