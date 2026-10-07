import SwiftUI

struct FullPlayerView: View {
    @EnvironmentObject var player: AudioPlayerManager
    @EnvironmentObject var theme: ThemeSettings
    @Environment(\.dismiss) var dismiss
    @State private var sliderValue: Double = 0
    @State private var isSeeking = false
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down")
                        .font(.title2)
                        .foregroundColor(theme.textColor)
                }
                .padding()
            }
            
            Spacer()
            
            // 封面占位
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.accentColor.opacity(0.3))
                .frame(width: 280, height: 280)
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(theme.accentColor)
                )
            
            // 歌曲信息
            if let track = player.currentTrack {
                VStack(spacing: 8) {
                    Text(track.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(theme.textColor)
                    Text(track.artist)
                        .foregroundColor(theme.secondaryTextColor)
                }
            }
            
            // 进度条
            VStack {
                Slider(
                    value: Binding(
                        get: { isSeeking ? sliderValue : player.currentTime },
                        set: { sliderValue = $0 }
                    ),
                    in: 0...(player.duration > 0 ? player.duration : 1),
                    onEditingChanged: { editing in
                        isSeeking = editing
                        if !editing {
                            player.seek(to: sliderValue)
                        }
                    }
                )
                .accentColor(theme.accentColor)
                
                HStack {
                    Text(formatTime(isSeeking ? sliderValue : player.currentTime))
                    Spacer()
                    Text(formatTime(player.duration))
                }
                .font(.caption)
                .foregroundColor(theme.secondaryTextColor)
            }
            .padding(.horizontal, 32)
            
            // 控制按钮
            HStack(spacing: 50) {
                Button { player.previous() } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 28))
                }
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 28))
                }
            }
            .foregroundColor(theme.textColor)
            
            Spacer()
        }
        .background(theme.backgroundColor.ignoresSafeArea())
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
