import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var api: NeteaseAPI
    @EnvironmentObject var theme: ThemeSettings
    @State private var keyword = ""
    @State private var artists: [OnlineArtist] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    TextField("搜索歌手", text: $keyword, onCommit: search)
                        .textFieldStyle(.roundedBorder)
                    Button("搜索", action: search)
                }
                .padding()
                if isSearching { ProgressView().padding() }
                List(artists) { artist in
                    HStack {
                        Text(artist.name).foregroundColor(theme.textColor)
                        Spacer()
                        Text("\(artist.songCount)首").font(.caption).foregroundColor(theme.secondaryTextColor)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("歌手")
            .background(theme.backgroundColor.ignoresSafeArea())
        }
    }
    
    private func search() {
        guard !keyword.isEmpty else { return }
        isSearching = true
        Task {
            do {
                let results = try await api.searchArtists(keyword: keyword)
                await MainActor.run {
                    artists = results
                    isSearching = false
                }
            } catch {
                await MainActor.run { isSearching = false }
            }
        }
    }
}
