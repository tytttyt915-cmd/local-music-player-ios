import SwiftUI

/// v3 在线搜索：多音源（网易云/QQ/酷狗/酷我/咪咕）+ 歌单搜索
struct OnlineSearchView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss

    @State private var keyword = ""
    @State private var songs: [OnlineSong] = []
    @State private var playlists: [OnlinePlaylist] = []
    @State private var selectedSource: MusicSource = .netease
    @State private var searchTab = 0 // 0 歌曲，1 歌单
    @State private var isSearching = false
    @State private var selectedPlaylist: OnlinePlaylist?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 0) {
                    searchBar
                    sourcePicker
                    tabPicker
                    if isSearching {
                        ProgressView().tint(.white).padding(40)
                    } else if searchTab == 0 {
                        songResults
                    } else {
                        playlistResults
                    }
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .sheet(item: $selectedPlaylist) { pl in
                PlaylistDetailView(playlist: pl)
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜索歌曲、歌手…", text: $keyword)
                .foregroundColor(.white)
                .onSubmit { Task { await doSearch() } }
            if !keyword.isEmpty {
                Button { keyword = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            Button("搜索") {
                Task { await doSearch() }
            }
            .foregroundColor(.accentColor)
        }
        .padding(12)
        .background(Capsule().fill(Color.white.opacity(0.1)))
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var sourcePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MusicSource.allCases) { src in
                    Button {
                        selectedSource = src
                        if !keyword.isEmpty {
                            Task { await doSearch() }
                        }
                    } label: {
                        Text(src.rawValue)
                            .font(.caption)
                            .foregroundColor(selectedSource == src ? .white : .gray)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selectedSource == src ? Color.accentColor : Color.white.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }

    private var tabPicker: some View {
        Picker("", selection: $searchTab) {
            Text("歌曲").tag(0)
            Text("歌单").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var songResults: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 2) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    OnlineSongRow(song: song, index: index) {
                        player.playOnlineSongs(songs, startAt: index)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 40)
        }
    }

    private var playlistResults: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(playlists) { pl in
                    Button { selectedPlaylist = pl } label: {
                        HStack(spacing: 12) {
                            AsyncImageView(url: pl.coverURL, size: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pl.title).foregroundColor(.white).lineLimit(1)
                                Text("\(pl.trackCount) 首 · ▶ \(pl.playCount.playCountText)")
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
    }

    private func doSearch() async {
        guard !keyword.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            if searchTab == 0 {
                songs = try await NeteaseAPI.shared.searchSongs(
                    keyword: keyword, source: selectedSource)
            } else {
                playlists = try await NeteaseAPI.shared.searchPlaylists(keyword: keyword)
            }
        } catch {
            print("搜索失败: \(error)")
        }
    }
}
