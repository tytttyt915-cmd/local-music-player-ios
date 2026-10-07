import SwiftUI

/// 主容器：5 Tab + MiniPlayer + FullPlayer
struct ContentView: View {
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var library: LibraryStore
    @EnvironmentObject var favorites: FavoriteStore
    @EnvironmentObject var theme: ThemeSettings
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var api: NeteaseAPI
    
    @State private var selectedTab = 0
    @State private var showFullPlayer = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                theme.backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Group {
                        switch selectedTab {
                        case 0: DiscoverView()
                        case 1: PlaylistPlazaView()
                        case 2: ArtistsView()
                        case 3: LocalMusicView()
                        case 4: ProfileView()
                        default: DiscoverView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    Spacer().frame(height: bottomInset(geo: geo))
                }
                
                VStack(spacing: 0) {
                    if player.currentTrack != nil {
                        MiniPlayerBar { showFullPlayer = true }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 6)
                    }
                    tabBar(geo: geo)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showFullPlayer) {
            FullPlayerView()
                .environmentObject(player)
                .environmentObject(theme)
        }
    }
    
    private func bottomInset(geo: GeometryProxy) -> CGFloat {
        let mini: CGFloat = player.currentTrack != nil ? 68 : 0
        return 84 + mini + geo.safeAreaInsets.bottom
    }
    
    private func tabBar(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                Button { selectedTab = i } label: {
                    VStack(spacing: 3) {
                        Image(systemName: icon(i)).font(.system(size: 20))
                        Text(title(i)).font(.system(size: 10))
                    }
                    .foregroundColor(selectedTab == i ? theme.accentColor : .gray)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.top, 10)
        .padding(.bottom, geo.safeAreaInsets.bottom + 10)
        .background(theme.backgroundColor.opacity(0.95))
    }
    
    private func icon(_ i: Int) -> String {
        ["safari", "music.note.list", "mic.fill", "folder.fill", "person.fill"][i]
    }
    private func title(_ i: Int) -> String {
        ["发现", "歌单", "歌手", "本地", "我的"][i]
    }
}
