import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var library = LibraryStore()
    @StateObject private var player = AudioPlayerManager()
    @StateObject private var favorites = FavoriteStore()

    @State private var showPlayer = false

    var body: some View {
        ZStack {
            TabView {
                LocalLibraryView()
                    .tabItem {
                        Label("本地", systemImage: "music.note.house")
                    }

                SearchView()
                    .tabItem {
                        Label("发现", systemImage: "magnifyingglass")
                    }
            }
            .tint(.cyan)

            VStack {
                Spacer()
                PlayerBar { showPlayer = true }
            }
        }
        .environmentObject(player)
        .environmentObject(library)
        .environmentObject(favorites)
        .sheet(isPresented: $showPlayer) {
            PlayerDetailView()
        }
    }
}

/// 本地 Tab：原来的首页内容（电台卡片 / 快捷操作 / 本地歌曲列表）
struct LocalLibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var favorites: FavoriteStore

    @State private var showImporter = false
    @State private var searchText = ""
    @State private var favoritesOnly = false
    @State private var quoteIndex = 0

    private let quotes = [
        "音乐是灵魂的避难所。",
        "没有音乐，生活将空无一物。",
        "深夜电台，为你守候。",
        "把耳朵交给星空。",
        "每一首歌都是一次短暂的旅行。",
        "旋律所至，皆是远方。",
        "在黑夜里，听见光。",
        "好歌值得单曲循环。"
    ]

    private var filtered: [Track] {
        var list = library.tracks
        if favoritesOnly {
            list = list.filter { favorites.ids.contains($0.id) }
        }
        if !searchText.isEmpty {
            list = list.filter {
                $0.title.localizedCaseInsensitiveContains(searchText)
                    || $0.artist.localizedCaseInsensitiveContains(searchText)
                    || $0.album.localizedCaseInsensitiveContains(searchText)
            }
        }
        return list
    }

    private var favoriteTracks: [Track] {
        library.tracks.filter { favorites.ids.contains($0.id) }
    }

    var body: some View {
        ZStack {
            StarfieldView()

            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    quickActions
                    searchBar

                    if library.tracks.isEmpty && !library.isLoading {
                        emptyState
                    } else {
                        sectionTitle(en: "TRACKS", zh: favoritesOnly ? "我的收藏" : "本地歌曲", count: filtered.count)
                        trackList

                        if !favoritesOnly && !favoriteTracks.isEmpty {
                            sectionTitle(en: "FAVORITES", zh: "我的收藏", count: favoriteTracks.count)
                            favoriteList
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task { await library.importFiles(urls) }
            case .failure(let error):
                print("导入失败: \(error)")
            }
        }
    }

    // MARK: - Hero
    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MINIPLAYER · 本地电台")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundColor(.gray)

            HStack(alignment: .bottom) {
                TimelineView(.everyMinute) { timeline in
                    Text(clockText(from: timeline.date))
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .cyan],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                }
                Spacer()
                Text(dateText(from: Date()))
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            HStack {
                Text("“\(quotes[quoteIndex % quotes.count])”")
                    .font(.callout)
                    .italic()
                    .foregroundColor(.white.opacity(0.85))
                Spacer()
                Button("换一条") { quoteIndex += 1 }
                    .font(.caption)
                    .foregroundColor(.cyan)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Quick actions
    private var quickActions: some View {
        HStack(spacing: 12) {
            actionCard(icon: "square.and.arrow.down", title: "导入音乐", en: "IMPORT") {
                showImporter = true
            }
            actionCard(icon: "heart", title: favoritesOnly ? "全部歌曲" : "我的收藏",
                       en: "FAVORITES", active: favoritesOnly) {
                favoritesOnly.toggle()
            }
            actionCard(icon: "shuffle", title: "随机播放", en: "SHUFFLE") {
                guard !filtered.isEmpty else { return }
                player.setShuffle(true)
                player.play(tracks: filtered, startAt: Int.random(in: 0..<filtered.count))
            }
        }
    }

    private func actionCard(icon: String, title: String, en: String,
                            active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(colors: [.cyan.opacity(0.85), .blue.opacity(0.85)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .foregroundColor(.white)
                        .font(.title3)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
                Text(en)
                    .font(.system(size: 9))
                    .tracking(2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(active ? 0.12 : 0.05))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜索歌曲、歌手、专辑…", text: $searchText)
                .foregroundColor(.white)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Capsule().fill(Color.white.opacity(0.07)))
    }

    // MARK: - Lists
    private func sectionTitle(en: String, zh: String, count: Int) -> some View {
        HStack(alignment: .lastTextBaseline) {
            Text(en)
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundColor(.gray)
            Text(zh)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 4)
    }

    private var trackList: some View {
        let list = filtered
        return LazyVStack(spacing: 4) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track) {
                    player.play(tracks: list, startAt: index)
                }
            }
        }
    }

    private var favoriteList: some View {
        let list = favoriteTracks
        return LazyVStack(spacing: 4) {
            ForEach(Array(list.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track) {
                    player.play(tracks: list, startAt: index)
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
            Text("点击「导入音乐」从文件添加音频")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [8]))
                .foregroundColor(.gray.opacity(0.4))
        )
    }

    // MARK: - Helpers
    private func clockText(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func dateText(from date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f.string(from: date)
    }
}
