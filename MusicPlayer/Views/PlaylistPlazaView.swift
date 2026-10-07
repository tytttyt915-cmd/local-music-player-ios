import SwiftUI

struct PlaylistPlazaView: View {
    @EnvironmentObject var api: NeteaseAPI
    @EnvironmentObject var theme: ThemeSettings
    @State private var keyword = ""
    @State private var playlists: [OnlinePlaylist] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("搜索歌单", text: $keyword, onCommit: search)
                        .textFieldStyle(.roundedBorder)
                    Button("搜索", action: search)
                }
                .padding()
                if isSearching { ProgressView().padding() }
                List(playlists) { playlist in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(playlist.title).foregroundStyle(theme.textColor)
                            Text("\(playlist.creator) · \(playlist.trackCount)首")
                                .font(.caption)
                                .foregroundStyle(theme.secondaryTextColor)
                        }
                        Spacer()
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("歌单广场")
            .background(theme.backgroundColor.ignoresSafeArea())
        }
    }
    
    private func search() {
        guard !keyword.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let results = try await api.searchPlaylists(keyword: keyword)
                await MainActor.run {
                    playlists = results
                    isSearching = false
                }
            } catch {
                await MainActor.run { isSearching = false }
            }
        }
    }
}
