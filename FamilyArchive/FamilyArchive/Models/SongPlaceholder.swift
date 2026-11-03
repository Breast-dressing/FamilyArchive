import Foundation

/// 空状态播放器用的占位歌曲：只提供占位封面 / 「未在播放」等文案，
/// 让 MeloX 的播放器可以按正常布局渲染。
extension Song {
    static let placeholder = Song(
        id: 0,
        name: "未在播放",
        artists: [],
        album: nil,
        durationMS: 0
    )
}
