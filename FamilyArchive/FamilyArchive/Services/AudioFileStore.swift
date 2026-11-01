import Foundation

/// 本地音频仓库：＋ 导入的音频复制进 App 沙盒，`Song.fileName` 只存相对名。
struct AudioFileStore {
    static let folderName = "Songs"

    /// 沙盒 Documents。
    static var defaultBaseDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    let baseDirectory: URL

    init(baseDirectory: URL = AudioFileStore.defaultBaseDirectory) {
        self.baseDirectory = baseDirectory
    }

    var folderURL: URL {
        baseDirectory.appendingPathComponent(Self.folderName, isDirectory: true)
    }

    /// 复制一份到仓库，返回相对文件名（`<uuid>.<ext>`）。
    @discardableResult
    func importAudio(from source: URL) throws -> String {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let ext = source.pathExtension
        let name = ext.isEmpty ? UUID().uuidString : "\(UUID().uuidString).\(ext)"
        let destination = folderURL.appendingPathComponent(name)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
        return name
    }

    func url(forFileName name: String) -> URL {
        folderURL.appendingPathComponent(name)
    }

    func exists(fileName name: String) -> Bool {
        !name.isEmpty && FileManager.default.fileExists(atPath: url(forFileName: name).path)
    }

    func delete(fileName name: String) throws {
        guard exists(fileName: name) else { return }
        try FileManager.default.removeItem(at: url(forFileName: name))
    }
}
