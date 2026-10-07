import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var api: NeteaseAPI
    @EnvironmentObject var theme: ThemeSettings
    @State private var artists: [OnlineArtist] = []
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView().padding()
                } else {
                    List(artists) { artist in
                        HStack {
                            Text(artist.name).foregroundStyle(theme.textColor)
                            Spacer()
                            Text("\(artist.songCount)首").font(.caption).foregroundStyle(theme.secondaryTextColor)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("歌手")
            .background(theme.backgroundColor.ignoresSafeArea())
        }
        .onAppear { load() }
    }
    
    private func load() {
        isLoading = true
        Task {
            do {
                let results = try await api.topArtists()
                await MainActor.run {
                    artists = results
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
