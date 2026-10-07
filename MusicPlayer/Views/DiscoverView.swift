import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var api: NeteaseAPI
    @EnvironmentObject var theme: ThemeSettings
    @State private var keyword = ""
    @State private var results: [Track] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            VStack {
                SearchBar(text: $keyword, onSearch: search)
                if isSearching { ProgressView().padding() }
                List(results) { track in
                    TrackRow(track: track)
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
                let tracks = try await api.search(keyword: keyword)
                await MainActor.run {
                    results = tracks
                    isSearching = false
                }
            } catch {
                await MainActor.run { isSearching = false }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void
    var body: some View {
        HStack {
            TextField("搜索歌曲", text: $text, onCommit: onSearch)
                .textFieldStyle(.roundedBorder)
            Button("搜索", action: onSearch)
        }
        .padding()
    }
}
