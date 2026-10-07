import SwiftUI

// 清理专辑/歌单名称末尾的多余标点
private func cleanTitle(_ s: String) -> String {
    var t = s.trimmingCharacters(in: .whitespacesAndNewlines)
    while let last = t.last, ",，.。、;；:：!！?？".contains(last) {
        t.removeLast()
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return t
}

/// v3 发现页：每日推荐 / 私人漫游 / 排行榜 / 新碟上架 / 推荐歌单 / 热门歌手
/// 样式对标参考 App；全部走网易云后端真实数据
struct DiscoverView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var theme: ThemeSettings

    @State private var playlists: [OnlinePlaylist] = []
    @State private var charts: [ChartItem] = []
    @State private var albums: [OnlineAlbum] = []
    @State private var artists: [OnlineArtist] = []
    @State private var isLoading = true
    @State private var showSearch = false
    @State private var showPlaylistPlaza = false
    @State private var selectedPlaylist: OnlinePlaylist?
    @State private var selectedArtist: OnlineArtist?

    var body: some View {
        GeometryReader { geo in
        ZStack {
            background

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    header
                    topCards
                    chartsSection
                    newAlbumsSection
                    recommendedPlaylistsSection
                    artistsSection
                }
                .padding(.top, max(geo.safeAreaInsets.top, 16) + 44)
                .padding(.bottom, 120)
                .frame(minHeight: geo.size.height)
            }
        }
        }
        .sheet(isPresented: $showSearch) { OnlineSearchView() }
        .sheet(isPresented: $showPlaylistPlaza) {
            NavigationView {
                PlaylistPlazaView()
            }
            .navigationViewStyle(.stack)
        }
        .sheet(item: $selectedPlaylist) { pl in
            PlaylistDetailView(playlist: pl)
        }
        .sheet(item: $selectedArtist) { artist in
            ArtistDetailView(artist: artist)
        }
        .task { await loadAll() }
    }

    // MARK: - Background（磨砂 + 壁纸，v1 星空主题已扔掉）
    private var background: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let data = theme.wallpaperData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.5)
            } else {
                // 默认渐变背景
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.08, blue: 0.12),
                             Color(red: 0.05, green: 0.05, blue: 0.08)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()
            }

            // 磨砂层
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.4)
                .ignoresSafeArea()
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("发现音乐")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(Date().discoverGreeting)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            // 右侧按钮组：水平排列，带间距
            HStack(spacing: 12) {
                // 搜索按钮（圆形）
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
                // 个人中心按钮（圆形头像）
                Button { showProfile = true } label: {
                    Group {
                        if let data = profile.avatarData, let img = UIImage(data: data) {
                            Image(uiImage: img).resizable().scaledToFill()
                        } else {
                            Circle().fill(Color.white.opacity(0.12))
                                .overlay(Image(systemName: "person.fill").foregroundColor(.white.opacity(0.7)))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - 每日推荐 / 私人漫游
    private var topCards: some View {
        HStack(spacing: 14) {
            // 每日推荐
            Button { showPlaylistPlaza = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Spacer()
                    Text("每日推荐")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("\(playlists.count) 个歌单 · 每天更新")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .frame(height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(colors: [Color(red: 0.9, green: 0.35, blue: 0.3),
                                                    Color(red: 0.55, green: 0.2, blue: 0.35)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
                .overlay(alignment: .topLeading) {
                    playlistCoverStack
                        .padding(14)
                }
            }
            .buttonStyle(.plain)

            // 私人漫游
            Button { startRoaming() } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text("私人漫游")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Text("从喜欢的歌开始漫游")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .frame(height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(colors: [Color(red: 0.35, green: 0.4, blue: 0.9),
                                                    Color(red: 0.5, green: 0.35, blue: 0.75)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    private var playlistCoverStack: some View {
        HStack(spacing: -8) {
            ForEach(playlists.prefix(3)) { pl in
                AsyncImageView(url: pl.coverURL, size: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.3)))
            }
        }
    }

    // MARK: - 排行榜
    private var chartsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "排行榜", action: {})
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(charts.prefix(6)) { chart in
                        Button { openChart(chart) } label: {
                            VStack(spacing: 8) {
                                ZStack {
                                    AsyncImageView(url: chart.coverURL, size: 110)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    LinearGradient(colors: [.clear, .black.opacity(0.45)],
                                                   startPoint: .top, endPoint: .bottom)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                    Text(chart.shortName)
                                        .font(.headline.bold())
                                        .foregroundColor(.white)
                                }
                                .frame(width: 110, height: 110)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 新碟上架
    private var newAlbumsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLinkRow(title: "新碟上架") { NewAlbumsView(albums: albums) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(albums.prefix(8)) { album in
                        VStack(spacing: 6) {
                            AsyncImageView(url: album.coverURL, size: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Text(album.title)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(1)
                                .frame(width: 100)
                            Text(album.artist)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                                .frame(width: 100)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - 推荐歌单
    private var recommendedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLinkRow(title: "推荐歌单") { PlaylistPlazaView() }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(playlists.prefix(6)) { pl in
                    Button { selectedPlaylist = pl } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            AsyncImageView(url: pl.coverURL, size: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Text(pl.title)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Text("▶ \(pl.playCount.playCountText)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - 热门歌手
    private var artistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLinkRow(title: "热门歌手") { ArtistsView(artists: artists) }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artists.prefix(10)) { artist in
                        Button { selectedArtist = artist } label: {
                            VStack(spacing: 8) {
                                AsyncImageView(url: artist.avatarURL, size: 64)
                                    .clipShape(Circle())
                                Text(artist.name)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                                    .frame(width: 70)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func sectionHeader(title: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.title3.bold())
                .foregroundColor(.white)
            Spacer()
            Button("更多", action: action)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Actions
    private func openChart(_ chart: ChartItem) {
        Task {
            do {
                let (_, songs) = try await NeteaseAPI.shared.playlistDetail(id: chart.id)
                let playlist = OnlinePlaylist(id: chart.id, title: chart.name,
                                              coverURL: chart.coverURL, creator: "",
                                              trackCount: songs.count, playCount: 0,
                                              description: chart.updateFrequency)
                selectedPlaylist = playlist
                // 预存歌曲，避免详情页二次加载闪烁（简化：直接打开）
            } catch {
                print("打开榜单失败: \(error)")
            }
        }
    }

    private func startRoaming() {
        // 私人漫游：从推荐歌单里随机抓歌开始播
        Task {
            do {
                let pls = try await NeteaseAPI.shared.personalized(limit: 3)
                guard let first = pls.first else { return }
                let (_, songs) = try await NeteaseAPI.shared.playlistDetail(id: first.id)
                guard !songs.isEmpty else { return }
                var shuffled = songs
                shuffled.shuffle()
                player.playOnlineSongs(shuffled)
            } catch {
                print("漫游失败: \(error)")
            }
        }
    }

    private func loadAll() async {
        async let pl: [OnlinePlaylist] = NeteaseAPI.shared.personalized(limit: 12)
        async let ch: [ChartItem] = NeteaseAPI.shared.toplist()
        async let al: [OnlineAlbum] = NeteaseAPI.shared.newestAlbums(limit: 12)
        async let ar: [OnlineArtist] = NeteaseAPI.shared.topArtists(limit: 20)
        do {
            let (p, c, a, r) = try await (pl, ch, al, ar)
            playlists = p; charts = c; albums = a; artists = r
        } catch {
            print("发现页加载失败: \(error)")
        }
        isLoading = false
    }
}

// MARK: - Helpers

struct NavigationLinkRow<Destination: View>: View {
    let title: String
    let destination: () -> Destination

    init(title: String, @ViewBuilder destination: @escaping () -> Destination) {
        self.title = title
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 20)
        }
    }
}

struct AsyncImageView: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Image(systemName: "music.note")
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

extension ChartItem {
    var shortName: String {
        // "热歌榜" -> 取前两字
        String(name.prefix(3))
    }
}

extension Int {
    var playCountText: String {
        if self >= 100_000_000 { return String(format: "%.1f亿", Double(self) / 100_000_000) }
        if self >= 10_000 { return String(format: "%.1f万", Double(self) / 10_000) }
        return "\(self)"
    }
}

extension Date {
    var discoverGreeting: String {
        let hour = Calendar.current.component(.hour, from: self)
        switch hour {
        case 6..<12: return "上午好，今天听点什么？"
        case 12..<14: return "中午好，来首歌提提神"
        case 14..<18: return "下午好，音乐陪你摸鱼"
        case 18..<23: return "晚上好，放松一下吧"
        default: return "夜深了，来首安静的歌"
        }
    }
}
