import Foundation

// MARK: - API Configuration

/// 后端网关配置
enum APIConfig {
    static let neteaseBase = "http://111.230.155.174:3000"
    static let realIP = "116.25.146.177"
}

// MARK: - Models

/// 在线歌曲（网易云）
struct OnlineSong: Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let album: String
    let albumId: Int
    let artworkURL: URL?
    let duration: Double // 秒
    let source: MusicSource

    static func == (lhs: OnlineSong, rhs: OnlineSong) -> Bool {
        lhs.id == rhs.id && lhs.source == rhs.source
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id); hasher.combine(source)
    }
}

/// 歌单
struct OnlinePlaylist: Identifiable, Hashable {
    let id: Int
    let title: String
    let coverURL: URL?
    let creator: String
    let trackCount: Int
    let playCount: Int
    let description: String

    static func == (lhs: OnlinePlaylist, rhs: OnlinePlaylist) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 歌手
struct OnlineArtist: Identifiable, Hashable {
    let id: Int
    let name: String
    let avatarURL: URL?
    let albumCount: Int
    let songCount: Int

    static func == (lhs: OnlineArtist, rhs: OnlineArtist) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 专辑
struct OnlineAlbum: Identifiable, Hashable {
    let id: Int
    let title: String
    let artist: String
    let coverURL: URL?
    let publishDate: String

    static func == (lhs: OnlineAlbum, rhs: OnlineAlbum) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 排行榜
struct ChartItem: Identifiable, Hashable {
    let id: Int
    let name: String
    let coverURL: URL?
    let updateFrequency: String

    static func == (lhs: ChartItem, rhs: ChartItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// 歌词行
struct LyricLine: Identifiable {
    let id = UUID()
    let time: Double
    let text: String
}

/// 评论
struct SongComment: Identifiable {
    let id: Int
    let user: String
    let avatarURL: URL?
    let content: String
    let likes: Int
    let time: String
}

// MARK: - Music Source

/// 音源：网易云 / QQ / 酷狗 / 酷我 / 咪咕 / 聚合
enum MusicSource: String, CaseIterable, Identifiable {
    case netease = "网易云"
    case qq = "QQ音乐"
    case kugou = "酷狗"
    case kuwo = "酷我"
    case migu = "咪咕"

    var id: String { rawValue }

    /// 各音源的后端基础路径（网关统一代理）
    var basePath: String {
        switch self {
        case .netease: return APIConfig.neteaseBase
        case .qq: return APIConfig.neteaseBase + "/qq"
        case .kugou: return APIConfig.neteaseBase + "/kugou"
        case .kuwo: return APIConfig.neteaseBase + "/kuwo"
        case .migu: return APIConfig.neteaseBase + "/migu"
        }
    }
}

/// 播放来源策略
enum PlaySourcePolicy: String, CaseIterable, Identifiable {
    case auto = "自动"
    case official = "官方"
    case thirdParty = "第三方"

    var id: String { rawValue }
}

/// 网络音质
enum AudioQuality: String, CaseIterable, Identifiable {
    case standard = "标准"
    case high = "高清"
    case lossless = "无损"

    var id: String { rawValue }

    /// 网易云 level 参数
    var neteaseLevel: String {
        switch self {
        case .standard: return "standard"
        case .high: return "exhigh"
        case .lossless: return "lossless"
        }
    }
}

// MARK: - Netease API Client

/// 网易云 API 客户端（经自建网关）
@MainActor
final class NeteaseAPI: ObservableObject {
    static let shared = NeteaseAPI()

    @Published var sourcePolicy: PlaySourcePolicy = .auto
    @Published var wifiQuality: AudioQuality = .high
    @Published var cellularQuality: AudioQuality = .standard

    private let session: URLSession
    private var urlCache: [Int: URL] = [:]

    private init() {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024,
                                   diskCapacity: 100 * 1024 * 1024,
                                   diskPath: "netease_api")
        self.session = URLSession(configuration: config)
    }

    // MARK: - Helpers

    private func get(_ path: String, params: [String: String] = [:]) async throws -> Data {
        var comps = URLComponents(string: APIConfig.neteaseBase + path)!
        comps.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        let (data, resp) = try await session.data(from: comps.url!)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw APIError.badResponse
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - Search

    /// 搜索歌曲（多音源聚合：按用户设置的来源策略）
    func searchSongs(keyword: String, source: MusicSource = .netease, limit: Int = 30) async throws -> [OnlineSong] {
        if source == .netease {
            return try await searchNetease(keyword: keyword, limit: limit)
        }
        // 其他音源经网关聚合接口
        return try await searchAggregated(keyword: keyword, source: source, limit: limit)
    }

    private func searchNetease(keyword: String, limit: Int) async throws -> [OnlineSong] {
        let data = try await get("/search", params: ["keywords": keyword, "limit": "\(limit)", "type": "1"])
        struct Resp: Decodable {
            struct Result: Decodable {
                struct Song: Decodable {
                    let id: Int
                    let name: String
                    struct Artist: Decodable { let name: String }
                    let artists: [Artist]
                    struct Album: Decodable { let name: String; let id: Int; let picUrl: String? }
                    let album: Album
                    let duration: Int
                }
                let songs: [Song]?
            }
            let result: Result?
        }
        let resp: Resp = try decode(data)
        return (resp.result?.songs ?? []).map { s in
            OnlineSong(id: s.id, title: s.name,
                       artist: s.artists.map(\.name).joined(separator: "/"),
                       album: s.album.name, albumId: s.album.id,
                       artworkURL: s.album.picUrl.flatMap(URL.init(string:)),
                       duration: Double(s.duration) / 1000.0,
                       source: .netease)
        }
    }

    private func searchAggregated(keyword: String, source: MusicSource, limit: Int) async throws -> [OnlineSong] {
        // 网关聚合搜索：/aggregate/search?source=qq&keywords=xxx
        let data = try await get("/aggregate/search",
                                 params: ["source": source.rawValue, "keywords": keyword, "limit": "\(limit)"])
        struct Resp: Decodable {
            struct Song: Decodable {
                let id: Int; let name: String; let artist: String
                let album: String; let picUrl: String?; let duration: Double
            }
            let songs: [Song]?
        }
        let resp: Resp = try decode(data)
        return (resp.songs ?? []).map { s in
            OnlineSong(id: s.id, title: s.name, artist: s.artist, album: s.album,
                       albumId: 0, artworkURL: s.picUrl.flatMap(URL.init(string:)),
                       duration: s.duration, source: source)
        }
    }

    /// 歌单搜索
    func searchPlaylists(keyword: String, limit: Int = 30) async throws -> [OnlinePlaylist] {
        let data = try await get("/search", params: ["keywords": keyword, "limit": "\(limit)", "type": "1000"])
        struct Resp: Decodable {
            struct Result: Decodable {
                struct PL: Decodable {
                    let id: Int; let name: String; let coverImgUrl: String?
                    struct Creator: Decodable { let nickname: String }
                    let creator: Creator?
                    let trackCount: Int; let playCount: Int
                    let description: String?
                }
                let playlists: [PL]?
            }
            let result: Result?
        }
        let resp: Resp = try decode(data)
        return (resp.result?.playlists ?? []).map { p in
            OnlinePlaylist(id: p.id, title: p.name,
                           coverURL: p.coverImgUrl.flatMap(URL.init(string:)),
                           creator: p.creator?.nickname ?? "",
                           trackCount: p.trackCount, playCount: p.playCount,
                           description: p.description ?? "")
        }
    }

    // MARK: - Song URL (with failover)

    /// 取播放链接；失败时按策略自动匹配其他平台同名歌曲
    func songURL(for song: OnlineSong) async throws -> URL {
        if let cached = urlCache[song.id] { return cached }

        let quality = currentQuality().neteaseLevel
        do {
            let url = try await fetchSongURL(id: song.id, level: quality)
            urlCache[song.id] = url
            return url
        } catch {
            // 自动换源：用同名在其他平台搜索
            if sourcePolicy != .official {
                if let fallback = try await matchOtherPlatform(song: song) {
                    return fallback
                }
            }
            throw error
        }
    }

    private func fetchSongURL(id: Int, level: String) async throws -> URL {
        let data = try await get("/song/url",
                                 params: ["id": "\(id)", "level": level,
                                          "realIP": APIConfig.realIP])
        struct Resp: Decodable {
            struct Item: Decodable { let url: String?; let id: Int }
            let data: [Item]?
        }
        let resp: Resp = try decode(data)
        guard let urlString = resp.data?.first?.url,
              let url = URL(string: urlString) else {
            throw APIError.noPlayableURL
        }
        return url
    }

    /// 播放失败时自动匹配其他平台同名歌曲
    private func matchOtherPlatform(song: OnlineSong) async throws -> URL? {
        for src in MusicSource.allCases where src != song.source {
            do {
                let results = try await searchAggregated(
                    keyword: "\(song.title) \(song.artist)", source: src, limit: 5)
                if let match = results.first {
                    return try await fetchSongURL(id: match.id, level: currentQuality().neteaseLevel)
                }
            } catch { continue }
        }
        return nil
    }

    private func currentQuality() -> AudioQuality {
        // 简化：按当前网络类型选择（实际可用 NWPathMonitor）
        return wifiQuality
    }

    // MARK: - Lyrics

    func lyrics(for songId: Int) async throws -> [LyricLine] {
        let data = try await get("/lyric", params: ["id": "\(songId)"])
        struct Resp: Decodable {
            struct LRC: Decodable { let lyric: String? }
            let lrc: LRC?
        }
        let resp: Resp = try decode(data)
        return parseLRC(resp.lrc?.lyric ?? "")
    }

    private func parseLRC(_ lrc: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        for raw in lrc.components(separatedBy: .newlines) {
            // [mm:ss.xx]text
            let pattern = #"\[(\d+):(\d+)(?:\.(\d+))?\](.*)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
                  match.numberOfRanges >= 5,
                  let mRange = Range(match.range(at: 1), in: raw),
                  let sRange = Range(match.range(at: 2), in: raw),
                  let tRange = Range(match.range(at: 4), in: raw)
            else { continue }
            let m = Double(raw[mRange]) ?? 0
            let s = Double(raw[sRange]) ?? 0
            var ms: Double = 0
            if match.range(at: 3).location != NSNotFound,
               let msRange = Range(match.range(at: 3), in: raw) {
                let msStr = String(raw[msRange])
                ms = (Double(msStr) ?? 0) / pow(10.0, Double(msStr.count))
            }
            let text = String(raw[tRange]).trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            lines.append(LyricLine(time: m * 60 + s + ms, text: text))
        }
        return lines.sorted { $0.time < $1.time }
    }

    // MARK: - Comments

    func comments(for songId: Int, limit: Int = 30) async throws -> [SongComment] {
        let data = try await get("/comment/music",
                                 params: ["id": "\(songId)", "limit": "\(limit)"])
        struct Resp: Decodable {
            struct C: Decodable {
                let commentId: Int
                struct User: Decodable { let nickname: String; let avatarUrl: String? }
                let user: User
                let content: String
                let likedCount: Int
                let timeStr: String?
            }
            let comments: [C]?
        }
        let resp: Resp = try decode(data)
        return (resp.comments ?? []).map { c in
            SongComment(id: c.commentId, user: c.user.nickname,
                        avatarURL: c.user.avatarUrl.flatMap(URL.init(string:)),
                        content: c.content, likes: c.likedCount,
                        time: c.timeStr ?? "")
        }
    }

    // MARK: - Discover: personalized / toplist / albums / artists

    /// 推荐歌单（每日推荐 / 私人漫游的数据源）
    func personalized(limit: Int = 12) async throws -> [OnlinePlaylist] {
        let data = try await get("/personalized", params: ["limit": "\(limit)"])
        struct Resp: Decodable {
            struct Item: Decodable {
                let id: Int; let name: String; let picUrl: String?
                let playCount: Int; let copywriter: String?
            }
            let result: [Item]?
        }
        let resp: Resp = try decode(data)
        return (resp.result ?? []).map { p in
            OnlinePlaylist(id: p.id, title: p.name,
                           coverURL: p.picUrl.flatMap(URL.init(string:)),
                           creator: p.copywriter ?? "",
                           trackCount: 0, playCount: p.playCount,
                           description: "")
        }
    }

    /// 排行榜列表
    func toplist() async throws -> [ChartItem] {
        let data = try await get("/toplist")
        struct Resp: Decodable {
            struct List: Decodable {
                let id: Int; let name: String; let coverImgUrl: String?
                let updateFrequency: String?
            }
            let list: [List]?
        }
        let resp: Resp = try decode(data)
        return (resp.list ?? []).map { c in
            ChartItem(id: c.id, name: c.name,
                      coverURL: c.coverImgUrl.flatMap(URL.init(string:)),
                      updateFrequency: c.updateFrequency ?? "")
        }
    }

    /// 歌单详情（含歌曲列表）
    func playlistDetail(id: Int) async throws -> (playlist: OnlinePlaylist, songs: [OnlineSong]) {
        let data = try await get("/playlist/detail", params: ["id": "\(id)"])
        struct Resp: Decodable {
            struct PL: Decodable {
                let id: Int; let name: String; let coverImgUrl: String?
                struct Creator: Decodable { let nickname: String }
                let creator: Creator?
                let trackCount: Int; let playCount: Int
                let description: String?
            }
            struct Track: Decodable {
                let id: Int; let name: String
                struct Ar: Decodable { let name: String }
                let ar: [Ar]
                struct Al: Decodable { let name: String; let id: Int; let picUrl: String? }
                let al: Al
                let dt: Int
            }
            let playlist: PL?
            // 新版接口 songs 在 playlist.trackIds，完整歌曲需 /playlist/track/all；这里用简化版
            let songs: [Track]?
        }
        let resp: Resp = try decode(data)
        let pl = resp.playlist
        let playlist = OnlinePlaylist(
            id: pl?.id ?? id, title: pl?.name ?? "",
            coverURL: pl?.coverImgUrl.flatMap(URL.init(string:)),
            creator: pl?.creator?.nickname ?? "",
            trackCount: pl?.trackCount ?? 0, playCount: pl?.playCount ?? 0,
            description: pl?.description ?? "")
        let songs = (resp.songs ?? []).map { s in
            OnlineSong(id: s.id, title: s.name,
                       artist: s.ar.map(\.name).joined(separator: "/"),
                       album: s.al.name, albumId: s.al.id,
                       artworkURL: s.al.picUrl.flatMap(URL.init(string:)),
                       duration: Double(s.dt) / 1000.0, source: .netease)
        }
        // 若 songs 为空，尝试 /playlist/track/all
        if songs.isEmpty, let pid = pl?.id {
            return (playlist, try await playlistTracks(id: pid))
        }
        return (playlist, songs)
    }

    private func playlistTracks(id: Int, limit: Int = 100) async throws -> [OnlineSong] {
        let data = try await get("/playlist/track/all",
                                 params: ["id": "\(id)", "limit": "\(limit)"])
        struct Resp: Decodable {
            struct Song: Decodable {
                let id: Int; let name: String
                struct Ar: Decodable { let name: String }
                let ar: [Ar]
                struct Al: Decodable { let name: String; let id: Int; let picUrl: String? }
                let al: Al
                let dt: Int
            }
            let songs: [Song]?
        }
        let resp: Resp = try decode(data)
        return (resp.songs ?? []).map { s in
            OnlineSong(id: s.id, title: s.name,
                       artist: s.ar.map(\.name).joined(separator: "/"),
                       album: s.al.name, albumId: s.al.id,
                       artworkURL: s.al.picUrl.flatMap(URL.init(string:)),
                       duration: Double(s.dt) / 1000.0, source: .netease)
        }
    }

    /// 新碟上架
    func newestAlbums(limit: Int = 12) async throws -> [OnlineAlbum] {
        let data = try await get("/album/newest")
        struct Resp: Decodable {
            struct Al: Decodable {
                let id: Int; let name: String; let picUrl: String?
                struct Ar: Decodable { let name: String }
                let artists: [Ar]?
                let publishTime: Int?
            }
            let albums: [Al]?
        }
        let resp: Resp = try decode(data)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return (resp.albums ?? []).prefix(limit).map { a in
            let dateStr: String
            if let t = a.publishTime {
                dateStr = df.string(from: Date(timeIntervalSince1970: Double(t) / 1000))
            } else { dateStr = "" }
            return OnlineAlbum(id: a.id, title: a.name,
                               artist: (a.artists ?? []).map(\.name).joined(separator: "/"),
                               coverURL: a.picUrl.flatMap(URL.init(string:)),
                               publishDate: dateStr)
        }
    }

    /// 热门歌手
    func topArtists(limit: Int = 24) async throws -> [OnlineArtist] {
        let data = try await get("/top/artists", params: ["limit": "\(limit)"])
        struct Resp: Decodable {
            struct Ar: Decodable {
                let id: Int; let name: String; let picUrl: String?
                let albumSize: Int?
            }
            let artists: [Ar]?
        }
        let resp: Resp = try decode(data)
        return (resp.artists ?? []).map { a in
            OnlineArtist(id: a.id, name: a.name,
                         avatarURL: a.picUrl.flatMap(URL.init(string:)),
                         albumCount: a.albumSize ?? 0, songCount: 0)
        }
    }

    /// 歌手热门歌曲
    func artistSongs(artistId: Int, limit: Int = 50) async throws -> [OnlineSong] {
        let data = try await get("/artists", params: ["id": "\(artistId)"])
        struct Resp: Decodable {
            struct HotSong: Decodable {
                let id: Int; let name: String
                struct Ar: Decodable { let name: String }
                let ar: [Ar]
                struct Al: Decodable { let name: String; let id: Int; let picUrl: String? }
                let al: Al
                let dt: Int
            }
            let hotSongs: [HotSong]?
        }
        let resp: Resp = try decode(data)
        return (resp.hotSongs ?? []).prefix(limit).map { s in
            OnlineSong(id: s.id, title: s.name,
                       artist: s.ar.map(\.name).joined(separator: "/"),
                       album: s.al.name, albumId: s.al.id,
                       artworkURL: s.al.picUrl.flatMap(URL.init(string:)),
                       duration: Double(s.dt) / 1000.0, source: .netease)
        }
    }
}

enum APIError: Error {
    case badResponse
    case noPlayableURL
    case decoding
}
