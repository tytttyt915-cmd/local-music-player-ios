import SwiftUI

struct ArtistsView: View {
    @EnvironmentObject var api: NeteaseAPI
    @EnvironmentObject var theme: ThemeSettings
    @State private var artists: [OnlineArtist] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
                Text("歌手")
                    .font(.largeTitle.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
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
            
            .background(Color.clear)
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
