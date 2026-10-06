import SwiftUI

/// 全屏播放器：封面/歌词 / 进度 / 控制 / 音量 / 倍速 / 睡眠定时 / 评论 / 队列
struct PlayerDetailView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var favorites: FavoriteStore
    @EnvironmentObject private var library: LibraryStore

    @State private var draggingTime: Double?
    @State private var showSleepOptions = false
    @State private var showComments = false
    @State private var showLyrics = false

    private var onlineSongId: Int? { player.currentTrack?.onlineSongId }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            StarfieldView().opacity(0.6)

            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)

                if let track = player.currentTrack {
                    // 封面 / 歌词切换
                    Group {
                        if showLyrics, track.isOnline {
                            LyricsView(songId: onlineSongId)
                                .frame(height: 280)
                        } else {
                            ArtworkView(track: track)
                                .frame(width: 250, height: 250)
                                .cornerRadius(28)
                                .shadow(color: .cyan.opacity(0.25), radius: 30)
                        }
                    }
                    .onTapGesture {
                        if track.isOnline { showLyrics.toggle() }
                    }

                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            if track.isOnline {
                                Image(systemName: "cloud.fill")
                                    .font(.caption)
                                    .foregroundColor(.cyan.opacity(0.8))
                            }
                            Text(track.title)
                                .font(.title2).bold()
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        Text("\(track.artist) · \(track.album)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                        if track.isOnline {
                            Text("点击封面查看歌词")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                    }

                    // 进度条
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { draggingTime ?? player.currentTime },
                                set: { draggingTime = $0 }
                            ),
                            in: 0...max(player.duration, 1),
                            onEditingChanged: { editing in
                                if !editing, let t = draggingTime {
                                    player.seek(to: t)
                                    draggingTime = nil
                                }
                            }
                        )
                        .tint(.cyan)
                        HStack {
                            Text(timeText(draggingTime ?? player.currentTime))
                                .font(.caption).foregroundColor(.gray)
                            Spacer()
                            Text(timeText(player.duration))
                                .font(.caption).foregroundColor(.gray)
                        }
                    }

                    // 主控制
                    HStack(spacing: 32) {
                        Button { player.setShuffle(!player.isShuffled) } label: {
                            Image(systemName: "shuffle")
                                .foregroundColor(player.isShuffled ? .cyan : .gray)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)

                        Button { player.previous() } label: {
                            Image(systemName: "backward.fill")
                                .foregroundColor(.white)
                                .font(.title)
                        }
                        .buttonStyle(.plain)

                        Button { player.togglePlayPause() } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .foregroundColor(.black)
                                .font(.system(size: 30))
                                .frame(width: 76, height: 76)
                                .background(
                                    LinearGradient(colors: [.cyan, .blue],
                                                   startPoint: .topLeading,
                                                   endPoint: .bottomTrailing)
                                )
                                .clipShape(Circle())
                                .shadow(color: .cyan.opacity(0.4), radius: 20)
                        }
                        .buttonStyle(.plain)

                        Button { _ = player.next() } label: {
                            Image(systemName: "forward.fill")
                                .foregroundColor(.white)
                                .font(.title)
                        }
                        .buttonStyle(.plain)

                        Button { player.cycleRepeat() } label: {
                            Image(systemName: player.repeatMode.iconName)
                                .foregroundColor(player.repeatMode == .off ? .gray : .cyan)
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                    }

                    // 音量
                    HStack {
                        Image(systemName: "speaker.fill")
                            .foregroundColor(.gray).font(.caption)
                        Slider(value: $player.volume, in: 0...1)
                            .tint(.cyan)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.gray).font(.caption)
                    }

                    // 倍速 / 睡眠 / 评论 / 收藏 / 删除
                    HStack(spacing: 10) {
                        Button("\(player.rateText) 倍速") { player.cycleRate() }
                            .buttonStyle(.bordered).tint(.cyan)
                        Button(player.sleepText) { showSleepOptions = true }
                            .buttonStyle(.bordered).tint(.cyan)
                            .confirmationDialog("睡眠定时", isPresented: $showSleepOptions,
                                                titleVisibility: .visible) {
                                Button("关闭") { player.cancelSleepTimer() }
                                Button("15 分钟") { player.startSleepTimer(minutes: 15) }
                                Button("30 分钟") { player.startSleepTimer(minutes: 30) }
                                Button("60 分钟") { player.startSleepTimer(minutes: 60) }
                            }
                        if track.isOnline {
                            Button {
                                showComments = true
                            } label: {
                                Image(systemName: "bubble.left")
                            }
                            .buttonStyle(.bordered).tint(.cyan)
                        }
                        Button {
                            favorites.toggle(track)
                        } label: {
                            Image(systemName: favorites.isFavorite(track) ? "heart.fill" : "heart")
                        }
                        .buttonStyle(.bordered).tint(.pink)
                        if !track.isOnline {
                            Button(role: .destructive) {
                                library.delete(track)
                                favorites.remove(id: track.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered).tint(.red)
                        }
                    }
                    .font(.caption)

                    queueList
                } else {
                    Text("还没有播放的歌曲")
                        .foregroundColor(.gray)
                        .padding(.top, 60)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
        }
        .sheet(isPresented: $showComments) {
            if let track = player.currentTrack {
                CommentsView(songId: track.onlineSongId, songTitle: track.title)
            }
        }
    }

    private var queueList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QUEUE · 播放队列 (\(player.queue.count))")
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundColor(.gray)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { index, track in
                        HStack {
                            if player.currentTrack?.id == track.id {
                                Image(systemName: "waveform")
                                    .foregroundColor(.cyan).font(.caption)
                            }
                            if track.isOnline {
                                Image(systemName: "cloud")
                                    .foregroundColor(.cyan.opacity(0.7)).font(.caption2)
                            }
                            Text(track.title)
                                .foregroundColor(.white)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Text(track.durationText)
                                .font(.caption).foregroundColor(.gray)
                            Button { player.removeFromQueue(at: index) } label: {
                                Image(systemName: "xmark.circle")
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture { player.playTrackInQueue(track) }
                        Divider().background(Color.white.opacity(0.08))
                    }
                }
            }
            .frame(maxHeight: 200)
        }
    }

    private func timeText(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let t = Int(s)
        return String(format: "%d:%02d", t / 60, t % 60)
    }
}
