import SwiftUI

/// v3 主界面：发现 / 歌单 / 歌手 / 我的
/// - 修复 iPhone 13 大黑边：内容撑满全屏，正确处理安全区
/// - v1 星空主题已彻底移除
/// - 底部悬浮迷你播放条 + Apple Music 风格自动收缩底栏
struct ContentView: View {
    @StateObject private var library = LibraryStore()
    @StateObject private var player = AudioPlayerManager()
    @StateObject private var favorites = FavoriteStore()
    @StateObject private var theme = ThemeSettings()
    @StateObject private var profile = UserProfile()
    @StateObject private var api = NeteaseAPI.shared

    @State private var selectedTab = 0
    @State private var showFullPlayer = false
    @State private var showProfile = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 主内容：全屏，无黑边
            TabView(selection: $selectedTab) {
                NavigationView {
                    DiscoverView()
                        .navigationBarHidden(true)
                }
                .navigationViewStyle(.stack)
                .tag(0)

                NavigationView {
                    PlaylistPlazaView()
                }
                .navigationViewStyle(.stack)
                .tag(1)

                NavigationView {
                    ArtistsView(artists: [])
                }
                .navigationViewStyle(.stack)
                .tag(2)

                NavigationView {
                    LocalMusicView()
                }
                .navigationViewStyle(.stack)
                .tag(3)
            }
            .ignoresSafeArea() // 关键：内容撑满，消除黑边

            // 悬浮层：迷你播放条 + 自适应底栏
            VStack(spacing: 10) {
                Spacer()
                if player.currentTrack != nil {
                    MiniPlayerBar { showFullPlayer = true }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if !theme.tabBarHidden {
                    customTabBar
                }
            }
            .padding(.bottom, 8)
        }
        // "我的"入口：右上角
        .overlay(alignment: .topTrailing) {
            Button { showProfile = true } label: {
                Group {
                    if let data = profile.avatarData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .foregroundColor(.white.opacity(0.7))
                            )
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 52)
            .padding(.trailing, 20)
        }
        .environmentObject(player)
        .environmentObject(library)
        .environmentObject(favorites)
        .environmentObject(theme)
        .environmentObject(profile)
        .environmentObject(api)
        .accentColor(theme.accentColor)
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView()
        }
        .sheet(isPresented: $showProfile) {
            NavigationView {
                ProfileView()
            }
            .navigationViewStyle(.stack)
        }
    }

    // MARK: - 自适应底栏（Apple Music 风格自动收缩）
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(index: 0, icon: "house.fill", title: "发现")
            tabButton(index: 1, icon: "square.stack.fill", title: "歌单")
            tabButton(index: 2, icon: "mic.fill", title: "歌手")
            tabButton(index: 3, icon: "music.note.list", title: "本地")
            // "我的"同时在底栏
            Button { showProfile = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 20))
                    Text("我的")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
        )
        .padding(.horizontal, 20)
    }

    private func tabButton(index: Int, icon: String, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(selectedTab == index ? .accentColor : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                // 圆润样式：选中项胶囊高亮
                theme.tabBarStyle == .rounded && selectedTab == index
                    ? Capsule().fill(Color.accentColor.opacity(0.18))
                    : nil
            )
        }
        .buttonStyle(.plain)
    }
}

/// 本地音乐页（v3 重构：无星空主题，磨砂背景）
struct LocalMusicView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var favorites: FavoriteStore
    @EnvironmentObject private var theme: ThemeSettings

    @State private var showImporter = false
    @State private var searchText = ""
    @State private var favoritesOnly = false

    private var filtered: [Track] {
        var list = library.tracks
        if favoritesOnly {
            list = list.filter { favorites.ids.contains($0.id) }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let data = theme.wallpaperData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .ignoresSafeArea().opacity(0.4)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    searchBar
                    if filtered.isEmpty && !library.isLoading {
                        emptyState
                    } else {
                        trackList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 140)
            }
        }
        .navigationTitle("本地音乐")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Task { await library.importFiles(urls) }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("本地音乐")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text("\(library.tracks.count) 首歌曲")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            Button { showImporter = true } label: {
                Image(systemName: "plus")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜索本地歌曲…", text: $searchText)
                .foregroundColor(.white)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Capsule().fill(Color.white.opacity(0.1)))
    }

    private var trackList: some View {
        LazyVStack(spacing: 4) {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, track in
                LocalTrackRow(track: track) {
                    player.play(tracks: filtered, startAt: index)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("还没有导入音乐")
                .foregroundColor(.white)
            Button("导入音乐") { showImporter = true }
                .foregroundColor(.accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

/// 本地歌曲行（含收藏按钮）
struct LocalTrackRow: View {
    let track: Track
    let onTap: () -> Void
    @EnvironmentObject private var favorites: FavoriteStore

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                MiniCover(track: track)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    favorites.toggle(track)
                } label: {
                    Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                        .foregroundColor(favorites.isFavorite(track) ? .red : .gray)
                }
                .buttonStyle(.plain)
                Text(track.durationText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Theme accent color mapping

extension ThemeSettings {
    var accentColor: Color {
        switch accent {
        case .coral: return Color(red: 1.0, green: 0.42, blue: 0.42)
        case .violet: return Color(red: 0.6, green: 0.45, blue: 1.0)
        case .azure: return Color(red: 0.3, green: 0.65, blue: 1.0)
        case .mint: return Color(red: 0.35, green: 0.85, blue: 0.65)
        case .amber: return Color(red: 1.0, green: 0.7, blue: 0.3)
        }
    }
}
