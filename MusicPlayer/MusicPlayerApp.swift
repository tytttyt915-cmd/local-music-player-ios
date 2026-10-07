import SwiftUI

@main
struct MusicPlayerApp: App {
    @StateObject private var player = AudioPlayerManager()
    @StateObject private var library = LibraryStore()
    @StateObject private var favorites = FavoriteStore()
    @StateObject private var theme = ThemeSettings()
    @StateObject private var profile = UserProfile()
    @StateObject private var api = NeteaseAPI.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .environmentObject(library)
                .environmentObject(favorites)
                .environmentObject(theme)
                .environmentObject(profile)
                .environmentObject(api)
        }
    }
}
