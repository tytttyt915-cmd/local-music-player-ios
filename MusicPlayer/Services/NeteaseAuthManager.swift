import SwiftUI
import Combine

class NeteaseAuthManager: ObservableObject {
    static let shared = NeteaseAuthManager()
    @Published var isLoggedIn: Bool = false
    @Published var uid: Int = 0
    @Published var nickname: String = ""
    @Published var avatarURL: String = ""
    @Published var isVIP: Bool = false
    @Published var userPlaylists: [OnlinePlaylist] = []
    @AppStorage("netease_cookie") var cookie: String = ""
    private let session = URLSession.shared

    init() {
        if !cookie.isEmpty {
            self.isLoggedIn = true
            Task { await checkLoginStatusAndFetchProfile() }
        }
    }

    func getQRKey(baseURL: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/login/qr/key?timestamp=\(Date().timeIntervalSince1970)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await session.data(from: url)
        struct KeyResp: Decodable { struct D: Decodable { let unikey: String }; let data: D }
        return try JSONDecoder().decode(KeyResp.self, from: data).data.unikey
    }

    func getQRCodeImageURL(baseURL: String, key: String) -> URL? {
        URL(string: "\(baseURL)/login/qr/create?key=\(key)&qrimg=true&timestamp=\(Date().timeIntervalSince1970)")
    }

    func checkQRStatus(baseURL: String, key: String) async throws -> (code: Int, cookie: String?) {
        guard let url = URL(string: "\(baseURL)/login/qr/check?key=\(key)&timestamp=\(Date().timeIntervalSince1970)") else {
            throw URLError(.badURL)
        }
        let (data, _) = try await session.data(from: url)
        struct CheckResp: Decodable { let code: Int; let cookie: String? }
        let resp = try JSONDecoder().decode(CheckResp.self, from: data)
        return (resp.code, resp.cookie)
    }

    @MainActor
    func handleLoginSuccess(cookieStr: String) async {
        self.cookie = cookieStr
        self.isLoggedIn = true
        await checkLoginStatusAndFetchProfile()
    }

    @MainActor
    func checkLoginStatusAndFetchProfile() async {
        guard !cookie.isEmpty else { return }
        let baseURL = APIConfig.neteaseBase
        let encoded = cookie.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseURL)/user/account?cookie=\(encoded)") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let profile = json["profile"] as? [String: Any] {
                self.uid = profile["userId"] as? Int ?? 0
                self.nickname = profile["nickname"] as? String ?? "网易云用户"
                self.avatarURL = profile["avatarUrl"] as? String ?? ""
                self.isVIP = (profile["vipType"] as? Int ?? 0) > 0
                await fetchUserPlaylists(uid: self.uid, baseURL: baseURL)
            }
        } catch { print("网易云资料失败: \(error)") }
    }

    @MainActor
    private func fetchUserPlaylists(uid: Int, baseURL: String) async {
        let encoded = cookie.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "\(baseURL)/user/playlist?uid=\(uid)&cookie=\(encoded)") else { return }
        do {
            let (data, _) = try await session.data(from: url)
            struct Resp: Decodable {
                struct Item: Decodable {
                    let id: Int; let name: String; let coverImgUrl: String?
                    let trackCount: Int?; let playCount: Int?
                }
                let playlist: [Item]
            }
            let resp = try JSONDecoder().decode(Resp.self, from: data)
            self.userPlaylists = resp.playlist.map {
                OnlinePlaylist(
                    id: $0.id, title: $0.name,
                    coverURL: $0.coverImgUrl.flatMap(URL.init(string:)),
                    creator: "", trackCount: $0.trackCount ?? 0,
                    playCount: $0.playCount ?? 0, description: ""
                )
            }
        } catch { print("歌单失败: \(error)") }
    }

    @MainActor
    func logout() {
        self.cookie = ""; self.isLoggedIn = false; self.uid = 0
        self.nickname = ""; self.avatarURL = ""; self.isVIP = false
        self.userPlaylists = []
    }
}
