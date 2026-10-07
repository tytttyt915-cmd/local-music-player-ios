import SwiftUI

/// v3.1 主界面：完全重写
/// - 不用系统 TabView，全部自定义，GeometryReader 精确控制
/// - iPhone 13 (390x844) 实测：无黑边，内容撑满
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
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // 背景：撑满全屏（不设固定 frame，让 ignoresSafeArea 自然铺满）
                Color.black
                    .ignoresSafeArea()

                if let data = theme.wallpaperData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .opacity(0.35)
                }

                // 主内容区：避开底栏
                VStack(spacing: 0) {
                    tabContent(geo: geo)
                    // 底栏占位
                    Color.clear.frame(height: bottomBarHeight(geo: geo))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                // 悬浮底栏：精确贴底，考虑安全区
                VStack(spacing: 0) {
                    if player.currentTrack != nil {
                        MiniPlayerBar { showFullPlayer = true }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }
                    if !theme.tabBarHidden {
                        customTabBar(geo: geo)
                    }
                }
                .background(Color.black.ignoresSafeArea(edges: .bottom))
            }
            .ignoresSafeArea()
        }

        .environmentObject(player)
        .environmentObject(library)
        .environmentObject(favorites)
        .environmentObject(theme)
        .environmentObject(profile)
        .environmentObject(api)
        .accentColor(theme.accentColor)
        .sheet(isPresented: $showFullPlayer) { FullPlayerView() }
        .sheet(isPresented: $showProfile) {
            NavigationView { 
                ProfileView()
                    .environmentObject(player)
                    .environmentObject(library)
                    .environmentObject(favorites)
                    .environmentObject(theme)
                    .environmentObject(profile)
                    .environmentObject(api)
            }.navigationViewStyle(.stack)
        }
    }

    // MARK: - 内容区

    @ViewBuilder
    private func tabContent(geo: GeometryProxy) -> some View {
        switch selectedTab {
        case 0: DiscoverView()
        case 1: PlaylistPlazaView()
        case 2: ArtistsView(artists: [])
        case 3: LocalMusicView()
        default: DiscoverView()
        }
    }

    private func bottomBarHeight(geo: GeometryProxy) -> CGFloat {
        var h: CGFloat = 76 // tab bar
        if player.currentTrack != nil { h += 68 } // mini player
        h += geo.safeAreaInsets.bottom + 16
        return h
    }

    // MARK: - 右上角头像

    private var profileButton: some View {
        Button { showProfile = true } label: {
            Group {
                if let data = profile.avatarData, let img = UIImage(data: data) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Circle().fill(Color.white.opacity(0.15))
                        .overlay(Image(systemName: "person.fill").foregroundColor(.white.opacity(0.7)))
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 54)
        .padding(.trailing, 20)
    }

    // MARK: - 底栏

    private func customTabBar(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            tabButton(index: 0, icon: "house.fill", title: "发现")
            tabButton(index: 1, icon: "square.stack.fill", title: "歌单")
            tabButton(index: 2, icon: "mic.fill", title: "歌手")
            tabButton(index: 3, icon: "music.note.list", title: "本地")
            Button { showProfile = true } label: {
                VStack(spacing: 4) {
                    Image(systemName: "person.fill").font(.system(size: 20))
                    Text("我的").font(.caption2)
                }
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, geo.safeAreaInsets.bottom + 4)
        .background(
            Color.black
                .ignoresSafeArea(edges: .bottom)
        )
        .background(.ultraThinMaterial)
    }

    private func tabButton(index: Int, icon: String, title: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                selectedTab = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 20))
                Text(title).font(.caption2)
            }
            .foregroundColor(selectedTab == index ? theme.accentColor : .white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                theme.tabBarStyle == .rounded && selectedTab == index
                    ? Capsule().fill(theme.accentColor.opacity(0.18))
                    : nil
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 本地音乐页（v3.1：GeometryReader 自适应，无黑边）

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
        if favoritesOnly { list = list.filter { favorites.ids.contains($0.id) } }
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                || $0.artist.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    var body: some View {
        GeometryReader { geo in
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
                .padding(.top, max(geo.safeAreaInsets.top, 16) + 44) // 避开右上角头像
                .padding(.bottom, 20)
                .frame(minHeight: geo.size.height)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("本地音乐").font(.system(size: 28, weight: .bold)).foregroundColor(.white)
                Text("\(library.tracks.count) 首歌曲").font(.subheadline).foregroundColor(.white.opacity(0.6))
            }
            Spacer()
            // 导入按钮：不与右上角头像重叠，放在标题行内
            Button { showImporter = true } label: {
                Image(systemName: "plus")
                    .font(.title3).foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(theme.accentColor))
            }
            .buttonStyle(.plain)
            .padding(.trailing, 52) // 给右上角头像留位置
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result {
                Task { await library.importFiles(urls) }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜索本地歌曲…", text: $searchText).foregroundColor(.white)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }.buttonStyle(.plain)
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
            Image(systemName: "music.note.list").font(.largeTitle).foregroundColor(.gray)
            Text("还没有导入音乐").foregroundColor(.white)
            Button("导入音乐") { showImporter = true }.foregroundColor(theme.accentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

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
                    Text(track.title).foregroundColor(.white).lineLimit(1)
                    Text(track.artist).font(.caption).foregroundColor(.gray).lineLimit(1)
                }
                Spacer()
                Button { favorites.toggle(track) } label: {
                    Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                        .foregroundColor(favorites.isFavorite(track) ? .red : .gray)
                }.buttonStyle(.plain)
                Text(track.durationText).font(.caption).foregroundColor(.gray)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
        }.buttonStyle(.plain)
    }
}

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
