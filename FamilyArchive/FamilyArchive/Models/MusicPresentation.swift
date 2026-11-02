//
//  MusicPresentation.swift
//  FamilyArchive
//
//  Pure layout / grouping rules for the 音乐 page so the logic tests can pin them.
//

import Foundation

enum MusicLayout {
    /// 自建歌单走三列。
    static let playlistColumns = 3
    /// 歌曲合集用横向长卡片。
    static let collectionCardHeight: CGFloat = 88
}

enum MusicLibrary {
    static func songs(_ songs: [Song], inPlaylist id: UUID) -> [Song] {
        songs
            .filter { $0.playlistID == id }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    static func songs(_ songs: [Song], inCollection id: UUID) -> [Song] {
        songs
            .filter { $0.collectionID == id }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    /// 没有归入歌单 / 合集的歌，进入「未分类」。
    static func looseSongs(_ songs: [Song]) -> [Song] {
        songs
            .filter { $0.playlistID == nil && $0.collectionID == nil }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }
}
