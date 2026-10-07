import SwiftUI

/// v3 歌单广场：独立页面，含歌单搜索
struct PlaylistPlazaView: View {
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var player: AudioPlayerManager
    @State private var playlists: [OnlinePlaylist] = []
    @State private var searchText = ""
    @State private var searchResults: [OnlinePlaylist] = []
    @State private var isSearching = false
    @State private var selectedPlaylist: OnlinePlaylist?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let data = theme.wallpaperData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .ignoresSafeArea().opacity(0.4)
            }

            VStack(spacing: 0) {
                searchBar
                ScrollView(showsIndicators: false) {
                    if isSearching {
                        searchResultList
                    } else {
                        plazaGrid
                    }
                }
            }
        }
        .navigationTitle("歌单广场")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedPlaylist) { pl in
            PlaylistDetailView(playlist: pl)
        }
        .task { await load() }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜索歌单…", text: $searchText)
                .foregroundColor(.white)
                .onSubmit { Task { await doSearch() } }
            if !searchText.isEmpty {
                Button { searchText = ""; isSearching = false } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Capsule().fill(Color.white.opacity(0.1)))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var plazaGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            ForEach(playlists) { pl in
                playlistCard(pl)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private var searchResultList: some View {
        LazyVStack(spacing: 12) {
            ForEach(searchResults) { pl in
                Button { selectedPlaylist = pl } label: {
                    HStack(spacing: 12) {
                        AsyncImageView(url: pl.coverURL, size: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pl.title).foregroundColor(.white).lineLimit(1)
                            Text("\(pl.trackCount) 首 · by \(pl.creator)")
                                .font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func playlistCard(_ pl: OnlinePlaylist) -> some View {
        Button { selectedPlaylist = pl } label: {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImageView(url: pl.coverURL, size: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text(pl.title)
                    .font(.subheadline).foregroundColor(.white)
                    .lineLimit(2).multilineTextAlignment(.leading)
                Text("▶ \(pl.playCount.playCountText)")
                    .font(.caption2).foregroundColor(.gray)
            }
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        do {
            playlists = try await NeteaseAPI.shared.personalized(limit: 30)
        } catch {
            print("歌单广场加载失败: \(error)")
        }
    }

    private func doSearch() async {
        guard !searchText.isEmpty else { isSearching = false; return }
        isSearching = true
        do {
            searchResults = try await NeteaseAPI.shared.searchPlaylists(keyword: searchText)
        } catch {
            print("歌单搜索失败: \(error)")
        }
    }
}

/// 歌单详情页
struct PlaylistDetailView: View {
    let playlist: OnlinePlaylist
    @EnvironmentObject private var player: AudioPlayerManager
    @State private var songs: [OnlineSong] = []
    @State private var isLoading = true

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    if isLoading {
                        ProgressView().tint(.white).padding(40)
                    } else {
                        playAllBar
                        songList
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .task { await loadSongs() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            AsyncImageView(url: playlist.coverURL, size: 110)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 8) {
                Text(playlist.title)
                    .font(.title3.bold()).foregroundColor(.white)
                    .lineLimit(3)
                if !playlist.creator.isEmpty {
                    Text("by \(playlist.creator)")
                        .font(.caption).foregroundColor(.gray)
                }
                Text("\(songs.count) 首")
                    .font(.caption).foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var playAllBar: some View {
        HStack {
            Button {
                player.setShuffle(false)
                player.playOnlineSongs(songs)
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("播放全部")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
            Button {
                player.setShuffle(true)
                player.playOnlineSongs(songs, startAt: Int.random(in: 0..<songs.count))
            } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text("随机播放")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20).padding(.vertical, 10)
                .background(Capsule().fill(Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private var songList: some View {
        LazyVStack(spacing: 2) {
            ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                OnlineSongRow(song: song, index: index) {
                    player.playOnlineSongs(songs, startAt: index)
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func loadSongs() async {
        do {
            let (_, list) = try await NeteaseAPI.shared.playlistDetail(id: playlist.id)
            songs = list
        } catch {
            print("歌单详情加载失败: \(error)")
        }
        isLoading = false
    }
}

/// 在线歌曲行
struct OnlineSongRow: View {
    let song: OnlineSong
    let index: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 24)
                AsyncImageView(url: song.artworkURL, size: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(song.artist) · \(song.album)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                Spacer()
                Text(song.durationText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        }
        .buttonStyle(.plain)
    }
}

extension OnlineSong {
    var durationText: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let total = Int(duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
