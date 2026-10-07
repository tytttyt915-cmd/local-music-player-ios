import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var api: NeteaseAPI
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var theme: ThemeSettings
    @State private var keyword = ""
    @State private var results: [OnlineSong] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("搜索歌曲", text: $keyword, onCommit: search)
                        .textFieldStyle(.roundedBorder)
                    Button("搜索", action: search)
                }
                .padding()
                if isSearching { ProgressView().padding() }
                List(results) { song in
                    Button {
                        if let idx = results.firstIndex(where: { $0.id == song.id }) {
                            player.playOnlineSongs(results, startAt: idx)
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(song.title).foregroundColor(theme.textColor)
                            Text(song.artist).font(.caption).foregroundColor(theme.secondaryTextColor)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("发现")
            .background(theme.backgroundColor.ignoresSafeArea())
        }
    }
    
    private func search() {
        guard !keyword.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let songs = try await api.searchSongs(keyword: keyword)
                await MainActor.run {
                    results = songs
                    isSearching = false
                }
            } catch {
                await MainActor.run { isSearching = false }
            }
        }
    }
}
