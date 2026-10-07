import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var theme: ThemeSettings
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                if let track = player.currentTrack {
                    VStack(alignment: .leading) {
                        Text(track.title).font(.subheadline).foregroundColor(theme.textColor)
                        Text(track.artist).font(.caption).foregroundColor(theme.secondaryTextColor)
                    }
                    Spacer()
                    Button { player.togglePlayPause() } label: {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(theme.textColor)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
