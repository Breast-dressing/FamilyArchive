import Foundation
import UniformTypeIdentifiers

/// File pickers are intentionally not restricted by UTTypes. After the user
/// picks files, photos and videos are rejected because those should come from
/// the system photo picker instead.
enum FileSelectionValidator {
    static func isPhotoOrVideo(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return false
        }
        return type.conforms(to: .image) || type.conforms(to: .movie)
    }

    static func partition(_ urls: [URL]) -> (accepted: [URL], rejected: [URL]) {
        var accepted: [URL] = []
        var rejected: [URL] = []
        for url in urls {
            if isPhotoOrVideo(url) {
                rejected.append(url)
            } else {
                accepted.append(url)
            }
        }
        return (accepted, rejected)
    }
}
