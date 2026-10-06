import Foundation

/// 单条音频。本地：id 为 Documents 下的文件名；在线：id 为 "online-<网易云歌曲ID>"。
struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let artworkData: Data?

    // MARK: - 在线歌曲扩展
    /// 是否为在线歌曲（来自网易云）
    let isOnline: Bool
    /// 网易云歌曲 ID（在线歌曲用）
    let onlineSongId: Int?
    /// 已解析的播放直链（在线歌曲用）
    let streamURL: URL?
    /// 远程专辑封面（在线歌曲用）
    let artworkURL: URL?

    init(id: String, title: String, artist: String, album: String,
         duration: Double, artworkData: Data?,
         isOnline: Bool = false, onlineSongId: Int? = nil,
         streamURL: URL? = nil, artworkURL: URL? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkData = artworkData
        self.isOnline = isOnline
        self.onlineSongId = onlineSongId
        self.streamURL = streamURL
        self.artworkURL = artworkURL
    }

    /// 本地文件 URL（仅本地歌曲有效）
    var fileURL: URL {
        LibraryStore.documentsDirectory.appendingPathComponent(id)
    }

    /// 实际播放用的 URL：在线用直链，本地用文件
    var playbackURL: URL {
        if isOnline, let streamURL { return streamURL }
        return fileURL
    }

    /// 从网易云搜索结果构造在线 Track（播放链接稍后解析）
    static func online(from song: NeteaseSearchSong, artworkURL: URL? = nil) -> Track {
        Track(
            id: "online-\(song.id)",
            title: song.name,
            artist: song.artistNames,
            album: song.album.name,
            duration: song.durationSeconds,
            artworkData: nil,
            isOnline: true,
            onlineSongId: song.id,
            streamURL: nil,
            artworkURL: artworkURL
        )
    }

    /// 填入解析到的播放链接，返回新的 Track
    func withStreamURL(_ url: URL) -> Track {
        Track(
            id: id, title: title, artist: artist, album: album,
            duration: duration, artworkData: artworkData,
            isOnline: isOnline, onlineSongId: onlineSongId,
            streamURL: url, artworkURL: artworkURL
        )
    }

    var durationText: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let total = Int(duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
