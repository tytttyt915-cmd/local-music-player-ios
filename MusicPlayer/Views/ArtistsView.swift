import SwiftUI

/// v3 歌手板块
struct ArtistsView: View {
    let artists: [OnlineArtist]
    @EnvironmentObject private var theme: ThemeSettings
    @State private var selectedArtist: OnlineArtist?
    @State private var list: [OnlineArtist]

    init(artists: [OnlineArtist]) {
        self.artists = artists
        _list = State(initialValue: artists)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let data = theme.wallpaperData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .ignoresSafeArea().opacity(0.35)
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                          spacing: 20) {
                    ForEach(list) { artist in
                        Button { selectedArtist = artist } label: {
                            VStack(spacing: 10) {
                                AsyncImageView(url: artist.avatarURL, size: 90)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                                Text(artist.name)
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                if artist.albumCount > 0 {
                                    Text("\(artist.albumCount) 张专辑")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("歌手")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedArtist) { artist in
            ArtistDetailView(artist: artist)
        }
        .task {
            if list.isEmpty {
                do {
                    list = try await NeteaseAPI.shared.topArtists(limit: 30)
                } catch {
                    print("歌手加载失败: \(error)")
                }
            }
        }
    }
}

/// 歌手详情页
struct ArtistDetailView: View {
    let artist: OnlineArtist
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
        VStack(spacing: 12) {
            AsyncImageView(url: artist.avatarURL, size: 120)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 2))
            Text(artist.name)
                .font(.title.bold())
                .foregroundColor(.white)
            if artist.songCount > 0 || artist.albumCount > 0 {
                Text("\(artist.songCount) 首歌曲 · \(artist.albumCount) 张专辑")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.top, 20)
    }

    private var playAllBar: some View {
        HStack {
            Button {
                player.setShuffle(false)
                player.playOnlineSongs(songs)
            } label: {
                HStack {
                    Image(systemName: "play.fill"); Text("播放全部")
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
                    Image(systemName: "shuffle"); Text("随机播放")
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
            songs = try await NeteaseAPI.shared.artistSongs(artistId: artist.id)
        } catch {
            print("歌手歌曲加载失败: \(error)")
        }
        isLoading = false
    }
}

/// v3 新碟上架页面
struct NewAlbumsView: View {
    let albums: [OnlineAlbum]
    @EnvironmentObject private var theme: ThemeSettings
    @State private var list: [OnlineAlbum]

    init(albums: [OnlineAlbum]) {
        self.albums = albums
        _list = State(initialValue: albums)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let data = theme.wallpaperData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .ignoresSafeArea().opacity(0.35)
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 18) {
                    ForEach(list) { album in
                        VStack(alignment: .leading, spacing: 8) {
                            AsyncImageView(url: album.coverURL, size: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            Text(album.title)
                                .font(.subheadline).foregroundColor(.white)
                                .lineLimit(2).multilineTextAlignment(.leading)
                            Text(album.artist)
                                .font(.caption).foregroundColor(.gray)
                                .lineLimit(1)
                            if !album.publishDate.isEmpty {
                                Text(album.publishDate)
                                    .font(.caption2).foregroundColor(.gray.opacity(0.7))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("新碟上架")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if list.isEmpty {
                do {
                    list = try await NeteaseAPI.shared.newestAlbums(limit: 24)
                } catch {
                    print("新碟加载失败: \(error)")
                }
            }
        }
    }
}
