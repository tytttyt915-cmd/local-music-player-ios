import SwiftUI
import UIKit

/// 发现 Tab：网易云搜索 + 在线播放
struct SearchView: View {
    @EnvironmentObject private var player: AudioPlayerManager

    @State private var keywords = ""
    @State private var results: [NeteaseSearchSong] = []
    @State private var artMap: [Int: URL] = [:]
    @State private var isSearching = false
    @State private var resolvingId: Int?
    @State private var alertMessage: String?
    @State private var hasSearched = false

    var body: some View {
        ZStack {
            StarfieldView()

            VStack(spacing: 12) {
                searchBar

                if isSearching {
                    Spacer()
                    ProgressView().tint(.cyan)
                    Text("搜索中…").font(.caption).foregroundColor(.gray)
                    Spacer()
                } else if !hasSearched {
                    Spacer()
                    emptyHint
                    Spacer()
                } else if results.isEmpty {
                    Spacer()
                    Text("没有找到相关歌曲")
                        .foregroundColor(.gray)
                    Spacer()
                } else {
                    resultList
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 110)
        }
        .alert("提示", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - 搜索栏
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("搜索网易云歌曲、歌手…", text: $keywords, onCommit: search)
                .foregroundColor(.white)
                .submitLabel(.search)
            if !keywords.isEmpty {
                Button { keywords = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
                .buttonStyle(.plain)
            }
            Button("搜索", action: search)
                .font(.subheadline).bold()
                .foregroundColor(.cyan)
                .buttonStyle(.plain)
                .disabled(keywords.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(12)
        .background(Capsule().fill(Color.white.opacity(0.07)))
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "cloud.sun")
                .font(.largeTitle)
                .foregroundColor(.cyan.opacity(0.7))
            Text("发现网易云音乐")
                .foregroundColor(.white)
            Text("搜索全网歌曲，在线播放 · 查看歌词 · 看评论")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    // MARK: - 结果列表
    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(results) { song in
                    OnlineTrackRow(
                        song: song,
                        artworkURL: artMap[song.id],
                        isResolving: resolvingId == song.id
                    ) {
                        play(song)
                    }
                }
            }
        }
    }

    // MARK: - 动作
    private func search() {
        let kw = keywords.trimmingCharacters(in: .whitespaces)
        guard !kw.isEmpty else { return }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                       to: nil, from: nil, for: nil)
        isSearching = true
        hasSearched = true
        Task {
            do {
                let songs = try await NeteaseAPI.search(keywords: kw)
                let arts = await NeteaseAPI.albumArtURLs(for: songs.map(\.id))
                await MainActor.run {
                    self.results = songs
                    self.artMap = arts
                    self.isSearching = false
                }
            } catch {
                await MainActor.run {
                    self.results = []
                    self.isSearching = false
                    self.alertMessage = (error as? LocalizedError)?.errorDescription ?? "搜索失败"
                }
            }
        }
    }

    /// 点播：解析直链 → 播放；无版权则如实提示
    private func play(_ song: NeteaseSearchSong) {
        guard resolvingId == nil else { return }
        resolvingId = song.id
        Task {
            do {
                let url = try await NeteaseAPI.streamURL(for: song.id)
                let track = Track.online(from: song, artworkURL: artMap[song.id])
                    .withStreamURL(url)
                await MainActor.run {
                    self.resolvingId = nil
                    self.player.play(tracks: [track], startAt: 0)
                }
            } catch NeteaseAPIError.noCopyright {
                await MainActor.run {
                    self.resolvingId = nil
                    self.alertMessage = "《\(song.name)》暂无版权，无法播放"
                }
            } catch {
                await MainActor.run {
                    self.resolvingId = nil
                    self.alertMessage = (error as? LocalizedError)?.errorDescription ?? "播放失败"
                }
            }
        }
    }
}

/// 在线歌曲行：封面 / 歌名 / 歌手 / 时长 / 云朵标识
struct OnlineTrackRow: View {
    let song: NeteaseSearchSong
    let artworkURL: URL?
    let isResolving: Bool
    var onTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let url = artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            GeometricPlaceholder(seed: "online-\(song.id)")
                        }
                    }
                } else {
                    GeometricPlaceholder(seed: "online-\(song.id)")
                }
            }
            .frame(width: 48, height: 48)
            .cornerRadius(12)
            .clipped()

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(song.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Image(systemName: "cloud")
                        .font(.caption2)
                        .foregroundColor(.cyan.opacity(0.8))
                }
                Text(song.artistNames)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            if isResolving {
                ProgressView()
                    .tint(.cyan)
                    .scaleEffect(0.8)
            } else {
                Text(song.durationText)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.clear))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private extension NeteaseSearchSong {
    var durationText: String {
        let total = Int(durationSeconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
