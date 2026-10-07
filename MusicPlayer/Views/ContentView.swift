import SwiftUI

/// 主界面 - 基于Beans模式重写
struct ContentView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @StateObject private var theme = ThemeSettings.shared
    @State private var selectedTab: Tab = .discover
    @State private var showFullPlayer = false
    
    enum Tab: String, CaseIterable {
        case discover = "发现"
        case playlist = "歌单"
        case artists = "歌手"
        case local = "本地"
        case profile = "我的"
        
        var icon: String {
            switch self {
            case .discover: return "safari"
            case .playlist: return "music.note.list"
            case .artists: return "mic"
            case .local: return "folder"
            case .profile: return "person"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // 背景层
            DynamicAuraBackground()
            
            // 内容层
            TabView(selection: $selectedTab) {
                DiscoverView()
                    .tag(Tab.discover)
                PlaylistPlazaView()
                    .tag(Tab.playlist)
                ArtistsView()
                    .tag(Tab.artists)
                LocalMusicView()
                    .tag(Tab.local)
                ProfileView()
                    .tag(Tab.profile)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 8) {
                // Mini播放器
                if player.currentTrack != nil {
                    MiniPlayerBar(onTap: { showFullPlayer = true })
                        .padding(.horizontal, 12)
                }
                // 悬浮胶囊TabBar
                floatingTabBar
            }
            .padding(.bottom, 8)
        }
        .environmentObject(player)
        .environmentObject(theme)
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView()
        }
        .ignoresSafeArea()
    }
    
    // 悬浮胶囊TabBar - 参考Beans的KumoneGlassTabBar
    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(selectedTab == tab ? theme.accentColor : .primary.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        if selectedTab == tab {
                            Capsule()
                                .fill(Color.primary.opacity(0.1))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(.regularMaterial)
        }
        .overlay {
            Capsule()
                .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }
}
