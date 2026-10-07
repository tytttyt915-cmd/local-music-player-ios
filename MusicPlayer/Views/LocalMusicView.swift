import SwiftUI

struct LocalMusicView: View {
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var theme: ThemeSettings
    
    var body: some View {
        NavigationView {
            Group {
                if library.tracks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note")
                            .font(.system(size: 60))
                            .foregroundColor(theme.secondaryTextColor)
                        Text("暂无本地音乐")
                            .foregroundColor(theme.secondaryTextColor)
                        Text("将音乐文件导入到 App 文档目录")
                            .font(.caption)
                            .foregroundColor(theme.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(library.tracks) { track in
                        TrackRow(track: track)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("本地")
            .background(theme.backgroundColor.ignoresSafeArea())
        }
        .onAppear { library.refresh() }
    }
}
