import Foundation

/// 统一曲目模型：本地文件 + 在线歌曲
/// v3: 支持在线 URL 播放、自定义封面、多音源
struct Track: Identifiable, Hashable {
    enum Kind: Hashable {
        case local
        case online(songId: Int, source: MusicSource)
    }

    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let artworkData: Data?
    let kind: Kind
    /// 在线封面 URL（在线歌曲用）
    let artworkURL: URL?
    /// 自定义封面（用户设置，本地缓存后持续生效）
    var customArtworkData: Data?

    /// 本地文件 URL（仅 local）
    var fileURL: URL {
        LibraryStore.documentsDirectory.appendingPathComponent(id)
    }

    /// 显示用封面数据：自定义 > 本地内嵌
    var displayArtworkData: Data? {
        customArtworkData ?? artworkData
    }

    var durationText: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let total = Int(duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var isOnline: Bool {
        if case .online = kind { return true }
        return false
    }

    var onlineSongId: Int? {
        if case .online(let sid, _) = kind { return sid }
        return nil
    }

    // 本地构造
    init(id: String, title: String, artist: String, album: String,
         duration: Double, artworkData: Data? = nil) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkData = artworkData
        self.kind = .local
        self.artworkURL = nil
        self.customArtworkData = nil
    }

    // 在线构造
    init(online song: OnlineSong) {
        self.id = "online-\(song.source.rawValue)-\(song.id)"
        self.title = song.title
        self.artist = song.artist
        self.album = song.album
        self.duration = song.duration
        self.artworkData = nil
        self.kind = .online(songId: song.id, source: song.source)
        self.artworkURL = song.artworkURL
        self.customArtworkData = nil
    }

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Playback stats

/// 播放统计：总播放次数 / 听歌时长（"我的"页展示）
final class PlaybackStats: ObservableObject {
    @Published private(set) var totalPlays: Int = 0
    @Published private(set) var totalSeconds: Double = 0

    private let playsKey = "stats.totalPlays"
    private let secondsKey = "stats.totalSeconds"

    init() {
        totalPlays = UserDefaults.standard.integer(forKey: playsKey)
        totalSeconds = UserDefaults.standard.double(forKey: secondsKey)
    }

    func recordPlay(duration: Double) {
        totalPlays += 1
        if duration.isFinite, duration > 0 {
            totalSeconds += duration
        }
        UserDefaults.standard.set(totalPlays, forKey: playsKey)
        UserDefaults.standard.set(totalSeconds, forKey: secondsKey)
        objectWillChange.send()
    }

    var listeningTimeText: String {
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        if hours > 0 {
            return "\(hours) 小时 \(minutes) 分钟"
        }
        return "\(minutes) 分钟"
    }
}

// MARK: - User profile

/// 用户资料：自定义昵称 + 头像（"我的"页）
final class UserProfile: ObservableObject {
    @Published var nickname: String {
        didSet { UserDefaults.standard.set(nickname, forKey: "profile.nickname") }
    }
    @Published var avatarData: Data? {
        didSet {
            if let data = avatarData {
                try? data.write(to: Self.avatarURL)
            } else {
                try? FileManager.default.removeItem(at: Self.avatarURL)
            }
        }
    }

    static var avatarURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("user-avatar.jpg")
    }

    init() {
        self.nickname = UserDefaults.standard.string(forKey: "profile.nickname") ?? "音乐爱好者"
        self.avatarData = try? Data(contentsOf: Self.avatarURL)
    }
}

// MARK: - App theme settings

/// 外观设置：壁纸 / 强调色 / 液态效果 / 底栏样式
final class ThemeSettings: ObservableObject {
    enum AccentChoice: String, CaseIterable, Identifiable {
        case coral = "珊瑚红"
        case violet = "鸢尾紫"
        case azure = "晴空蓝"
        case mint = "薄荷绿"
        case amber = "琥珀黄"

        var id: String { rawValue }
        var colorName: String { rawValue }
    }

    enum TabBarStyle: String, CaseIterable, Identifiable {
        case rounded = "圆润"
        case sfSymbols = "SF Symbols"

        var id: String { rawValue }
    }

    @Published var accent: AccentChoice {
        didSet { UserDefaults.standard.set(accent.rawValue, forKey: "theme.accent") }
    }
    @Published var wallpaperData: Data? {
        didSet { saveWallpaper() }
    }
    @Published var liquidEffectEnabled: Bool {
        didSet { UserDefaults.standard.set(liquidEffectEnabled, forKey: "theme.liquid") }
    }
    @Published var tabBarStyle: TabBarStyle {
        didSet { UserDefaults.standard.set(tabBarStyle.rawValue, forKey: "theme.tabbar") }
    }
    @Published var tabBarHidden: Bool {
        didSet { UserDefaults.standard.set(tabBarHidden, forKey: "theme.tabbarHidden") }
    }
    @Published var showDynamicIsland: Bool {
        didSet { UserDefaults.standard.set(showDynamicIsland, forKey: "theme.dynamicIsland") }
    }

    static var wallpaperURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("wallpaper.jpg")
    }

    init() {
        let accentRaw = UserDefaults.standard.string(forKey: "theme.accent") ?? AccentChoice.coral.rawValue
        self.accent = AccentChoice(rawValue: accentRaw) ?? .coral
        self.wallpaperData = try? Data(contentsOf: Self.wallpaperURL)
        self.liquidEffectEnabled = UserDefaults.standard.object(forKey: "theme.liquid") as? Bool ?? true
        let tbRaw = UserDefaults.standard.string(forKey: "theme.tabbar") ?? TabBarStyle.rounded.rawValue
        self.tabBarStyle = TabBarStyle(rawValue: tbRaw) ?? .rounded
        self.tabBarHidden = UserDefaults.standard.bool(forKey: "theme.tabbarHidden")
        self.showDynamicIsland = UserDefaults.standard.object(forKey: "theme.dynamicIsland") as? Bool ?? true
    }

    private func saveWallpaper() {
        if let data = wallpaperData {
            try? data.write(to: Self.wallpaperURL)
        } else {
            try? FileManager.default.removeItem(at: Self.wallpaperURL)
        }
    }
}
