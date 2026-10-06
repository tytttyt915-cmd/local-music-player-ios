import Foundation

// MARK: - Models

/// 搜索结果中的单曲
struct NeteaseSearchSong: Decodable, Identifiable {
    let id: Int
    let name: String
    let artists: [NeteaseArtist]
    let album: NeteaseAlbum
    /// 时长（毫秒）
    let duration: Int
    /// fee: 0 免费，1 VIP，4 专辑付费，8 无版权/需购买
    let fee: Int?

    var artistNames: String {
        artists.map(\.name).joined(separator: " / ")
    }

    var durationSeconds: Double { Double(duration) / 1000.0 }
}

struct NeteaseArtist: Decodable {
    let id: Int
    let name: String
}

struct NeteaseAlbum: Decodable {
    let id: Int
    let name: String
}

private struct SearchResponse: Decodable {
    struct Result: Decodable {
        let songs: [NeteaseSearchSong]?
    }
    let result: Result?
}

/// 歌曲详情（用于取专辑封面）
private struct SongDetailResponse: Decodable {
    struct Song: Decodable {
        struct Album: Decodable { let picUrl: String? }
        struct Artist: Decodable { let name: String }
        let id: Int
        let al: Album?
        let ar: [Artist]?
    }
    let songs: [Song]?
}

/// 播放链接
private struct SongURLResponse: Decodable {
    struct Item: Decodable {
        let url: String?
        let br: Int?
    }
    let data: [Item]?
}

/// 歌词
struct NeteaseLyric: Decodable {
    struct LyricBlock: Decodable { let lyric: String? }
    let lrc: LyricBlock?
    let tlyric: LyricBlock?
}

/// 评论
struct NeteaseComment: Decodable, Identifiable {
    struct User: Decodable { let nickname: String? }
    let user: User?
    let content: String?
    let timeStr: String?

    var id: String { "\(user?.nickname ?? "")-\(timeStr ?? "")-\(content?.prefix(12) ?? "")" }
    var nickname: String { user?.nickname ?? "匿名" }
    var text: String { content ?? "" }
    var time: String { timeStr ?? "" }
}

private struct CommentResponse: Decodable {
    let comments: [NeteaseComment]?
    let total: Int?
}

// MARK: - LRC 解析

struct LyricLine: Identifiable {
    let id = UUID()
    /// 秒
    let time: Double
    let text: String
    var translation: String?
}

enum LyricParser {
    /// 解析 LRC 文本，返回按时间排序的行。tlyric 为可选译文。
    static func parse(lrc: String?, tlyric: String?) -> [LyricLine] {
        guard let lrc, !lrc.isEmpty else { return [] }
        var lines: [LyricLine] = []
        let pattern = #"\[(\d+):(\d+)(?:\.(\d+))?\]"#
        let regex = try? NSRegularExpression(pattern: pattern)
        for raw in lrc.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let ns = line as NSString
            let matches = regex?.matches(in: line, range: NSRange(location: 0, length: ns.length)) ?? []
            guard let m = matches.first else { continue }
            let min = Double(ns.substring(with: m.range(at: 1))) ?? 0
            let sec = Double(ns.substring(with: m.range(at: 2))) ?? 0
            var ms: Double = 0
            if m.range(at: 3).location != NSNotFound {
                let frac = ns.substring(with: m.range(at: 3))
                // 可能是 2 位或 3 位小数
                let divisor = pow(10.0, Double(frac.count))
                ms = (Double(frac) ?? 0) / divisor
            }
            let time = min * 60 + sec + ms
            let textStart = m.range.upperBound
            let text = textStart < ns.length
                ? ns.substring(from: textStart).trimmingCharacters(in: .whitespaces)
                : ""
            guard !text.isEmpty else { continue }
            lines.append(LyricLine(time: time, text: text))
        }
        lines.sort { $0.time < $1.time }

        // 译文按时间对齐
        if let tlyric, !tlyric.isEmpty {
            var trans: [(Double, String)] = []
            for raw in tlyric.components(separatedBy: "\n") {
                let line = raw.trimmingCharacters(in: .whitespaces)
                guard !line.isEmpty else { continue }
                let ns = line as NSString
                guard let m = regex?.matches(in: line, range: NSRange(location: 0, length: ns.length)).first else { continue }
                let min = Double(ns.substring(with: m.range(at: 1))) ?? 0
                let sec = Double(ns.substring(with: m.range(at: 2))) ?? 0
                var ms: Double = 0
                if m.range(at: 3).location != NSNotFound {
                    let frac = ns.substring(with: m.range(at: 3))
                    ms = (Double(frac) ?? 0) / pow(10.0, Double(frac.count))
                }
                let textStart = m.range.upperBound
                let text = textStart < ns.length
                    ? ns.substring(from: textStart).trimmingCharacters(in: .whitespaces)
                    : ""
                if !text.isEmpty { trans.append((min * 60 + sec + ms, text)) }
            }
            for i in lines.indices {
                if let t = trans.first(where: { abs($0.0 - lines[i].time) < 0.5 }) {
                    lines[i].translation = t.1
                }
            }
        }
        return lines
    }
}

// MARK: - API Client

enum NeteaseAPIError: LocalizedError {
    case invalidURL
    case requestFailed
    case noCopyright
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "请求地址无效"
        case .requestFailed: return "网络请求失败，请检查网络"
        case .noCopyright: return "暂无版权，无法播放"
        case .decodeFailed: return "数据解析失败"
        }
    }
}

/// 自建网易云音乐 API 网关客户端
enum NeteaseAPI {
    static let baseURL = "http://111.230.155.174:3000"
    /// 机房 IP 被网易限制，取播放链接必须带真实出口 IP
    static let realIP = "116.25.146.177"

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private static func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw NeteaseAPIError.invalidURL
        }
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(from: url)
        } catch {
            throw NeteaseAPIError.requestFailed
        }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw NeteaseAPIError.requestFailed
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NeteaseAPIError.decodeFailed
        }
    }

    /// 搜索歌曲
    static func search(keywords: String, limit: Int = 20) async throws -> [NeteaseSearchSong] {
        let q = keywords.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keywords
        let resp: SearchResponse = try await get("/search?keywords=\(q)&limit=\(limit)")
        return resp.result?.songs ?? []
    }

    /// 批量取专辑封面（search 结果里没有 picUrl）
    static func albumArtURLs(for ids: [Int]) async -> [Int: URL] {
        guard !ids.isEmpty else { return [:] }
        let idStr = ids.map(String.init).joined(separator: ",")
        guard let resp: SongDetailResponse = try? await get("/song/detail?ids=\(idStr)") else {
            return [:]
        }
        var map: [Int: URL] = [:]
        for s in resp.songs ?? [] {
            if let pic = s.al?.picUrl, let url = URL(string: pic) {
                map[s.id] = url
            }
        }
        return map
    }

    /// 取播放链接（320k）。无版权时 url 为空 → 抛 noCopyright
    static func streamURL(for songId: Int, level: String = "exhigh") async throws -> URL {
        let resp: SongURLResponse = try await get(
            "/song/url/v1?id=\(songId)&level=\(level)&realIP=\(realIP)"
        )
        guard let item = resp.data?.first,
              let urlStr = item.url, !urlStr.isEmpty,
              let url = URL(string: urlStr) else {
            throw NeteaseAPIError.noCopyright
        }
        return url
    }

    /// 歌词（含译文）
    static func lyric(for songId: Int) async -> [LyricLine] {
        guard let resp: NeteaseLyric = try? await get("/lyric?id=\(songId)") else {
            return []
        }
        return LyricParser.parse(lrc: resp.lrc?.lyric, tlyric: resp.tlyric?.lyric)
    }

    /// 评论
    static func comments(for songId: Int, limit: Int = 20) async -> [NeteaseComment] {
        guard let resp: CommentResponse = try? await get("/comment/music?id=\(songId)&limit=\(limit)") else {
            return []
        }
        return resp.comments ?? []
    }
}
