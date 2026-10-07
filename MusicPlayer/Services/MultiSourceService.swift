import Foundation

/// 多音源服务：网易云 -> QQ音乐 -> 酷狗，自动切换
/// 参考 Beans UnblockService 设计
enum MultiSourceService {
    struct Resolved {
        let url: URL
        let source: String
    }
    
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 15
        return URLSession(configuration: config)
    }()
    
    /// 尝试从备用音源获取播放地址
    /// - Parameters:
    ///   - title: 歌曲名
    ///   - artist: 歌手名
    /// - Returns: 第一个可用的播放地址
    static func resolve(title: String, artist: String) async -> Resolved? {
        // 1. 试酷狗（公开API较稳定）
        if let url = await kugouURL(title: title, artist: artist) {
            return Resolved(url: url, source: "酷狗音乐")
        }
        // 2. QQ音乐需要vkey，暂不实现
        return nil
    }
    
    private static func kugouURL(title: String, artist: String) async -> URL? {
        let keyword = "\(title) \(artist)"
        guard let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        let searchURL = "https://songsearch.kugou.com/song_search_v2?keyword=\(encoded)&page=1&pagesize=3&platform=WebFilter"
        
        guard let url = URL(string: searchURL) else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await session.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataDict = json["data"] as? [String: Any],
                  let lists = dataDict["lists"] as? [[String: Any]],
                  let first = lists.first,
                  let fileHash = first["FileHash"] as? String,
                  let albumID = first["AlbumID"] as? Int else { return nil }
            
            let playURL = "https://wwwapi.kugou.com/yy/index.php?r=play/getdata&hash=\(fileHash)&album_id=\(albumID)"
            guard let purl = URL(string: playURL) else { return nil }
            let (pdata, _) = try await session.data(for: URLRequest(url: purl))
            guard let pjson = try JSONSerialization.jsonObject(with: pdata) as? [String: Any],
                  let pdataDict = pjson["data"] as? [String: Any],
                  let playUrlStr = pdataDict["play_url"] as? String,
                  !playUrlStr.isEmpty,
                  let result = URL(string: playUrlStr) else { return nil }
            return result
        } catch {
            return nil
        }
    }
}
