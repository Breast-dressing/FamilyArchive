import Foundation
import SwiftData
import SwiftUI
import UIKit

/// 音乐页内容：上方三列自建歌单，下方横向长卡片的歌曲合集。
struct MusicLibraryView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Playlist.sortOrder) private var playlists: [Playlist]
    @Query(sort: \SongCollection.sortOrder) private var collections: [SongCollection]
    @Query(sort: \Song.createdAt) private var songs: [Song]

    @State private var isCreatingPlaylist = false
    @State private var isCreatingCollection = false
    @State private var draftName = ""

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 12),
            count: MusicLayout.playlistColumns
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header("自建歌单") { startCreating(playlist: true) }

                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(playlists) { playlist in
                        playlistTile(playlist)
                    }
                }

                if playlists.isEmpty {
                    emptyHint("还没有歌单，点右上角 ＋ 新建。")
                }

                header("歌曲合集") { startCreating(playlist: false) }

                VStack(spacing: 12) {
                    ForEach(collections) { collection in
                        collectionCard(collection)
                    }
                }

                if collections.isEmpty {
                    emptyHint("还没有合集，点右上角 ＋ 新建。")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .alert("新建歌单", isPresented: $isCreatingPlaylist) {
            TextField("歌单名称", text: $draftName)
            Button("创建") { create(playlist: true) }
            Button("取消", role: .cancel) { draftName = "" }
        }
        .alert("新建合集", isPresented: $isCreatingCollection) {
            TextField("合集名称", text: $draftName)
            Button("创建") { create(playlist: false) }
            Button("取消", role: .cancel) { draftName = "" }
        }
    }

    private func header(_ title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
            Spacer()
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("新建\(title)")
        }
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func playlistTile(_ playlist: Playlist) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            cover(playlist.coverData)
                .frame(height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(playlist.name)
                .font(.footnote.weight(.semibold))
                .lineLimit(1)

            Text("\(MusicLibrary.songs(songs, inPlaylist: playlist.id).count) 首")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func collectionCard(_ collection: SongCollection) -> some View {
        HStack(spacing: 12) {
            cover(collection.coverData)
                .frame(width: MusicLayout.collectionCardHeight,
                       height: MusicLayout.collectionCardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(collection.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(MusicLibrary.songs(songs, inCollection: collection.id).count) 首")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func cover(_ data: Data?) -> some View {
        if let data, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .clipped()
        } else {
            ZStack {
                Rectangle().fill(.quaternary)
                Image(systemName: "music.note.list")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func startCreating(playlist: Bool) {
        draftName = ""
        if playlist {
            isCreatingPlaylist = true
        } else {
            isCreatingCollection = true
        }
    }

    private func create(playlist: Bool) {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        draftName = ""
        guard !name.isEmpty else { return }
        if playlist {
            modelContext.insert(Playlist(name: name, sortOrder: playlists.count))
        } else {
            modelContext.insert(SongCollection(name: name, sortOrder: collections.count))
        }
        try? modelContext.save()
    }
}
