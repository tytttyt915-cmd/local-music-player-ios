import SwiftUI

/// v3 全屏播放器：大封面 / 滚动歌词 / 评论 / 进度条
/// iOS 15+ 兼容；iOS 26+ 可选液态玻璃
struct FullPlayerView: View {
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var theme: ThemeSettings
    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics = true
    @State private var lyrics: [LyricLine] = []
    @State private var showComments = false
    @State private var showQueue = false
    @State private var showCoverPicker = false

    var body: some View {
        ZStack {
            // 背景：封面模糊
            PlayerBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 8)

                if showLyrics {
                    lyricsView
                } else {
                    coverView
                }

                Spacer(minLength: 8)
                songInfo
                progressBar
                controls
                bottomTools
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showComments) {
            if let track = player.currentTrack, let sid = track.onlineSongId {
                CommentsSheet(songId: sid)
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
        }
        .task(id: player.currentTrack?.id) {
            await loadLyrics()
        }
    }

    // MARK: - Top bar
    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("正在播放")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Button { showQueue = true } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Cover
    private var coverView: some View {
        Group {
            if let track = player.currentTrack {
                MiniCover(track: track)
                    .frame(width: 280, height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: .black.opacity(0.5), radius: 30)
                    .onTapGesture { showLyrics = true }
                    .contextMenu {
                        Button("自定义封面") { showCoverPicker = true }
                    }
            }
        }
    }

    // MARK: - Lyrics（滚动 + 同步高亮）
    private var lyricsView: some View {
        Group {
            if lyrics.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.4))
                    Text(player.currentTrack?.isOnline == true ? "歌词加载中…" : "本地歌曲暂无歌词")
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxHeight: 320)
                .onTapGesture { showLyrics = false }
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            ForEach(lyrics) { line in
                                Text(line.text)
                                    .font(.system(size: currentLineId == line.id ? 22 : 17,
                                                  weight: currentLineId == line.id ? .bold : .regular))
                                    .foregroundColor(currentLineId == line.id ? .white : .white.opacity(0.45))
                                    .multilineTextAlignment(.center)
                                    .id(line.id)
                                    .onTapGesture {
                                        // 点击歌词跳转
                                        player.seek(to: line.time)
                                    }
                                    .padding(.horizontal, 16)
                            }
                        }
                        .padding(.vertical, 120)
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: currentLineId) { newId in
                        if let id = newId {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo(id, anchor: .center)
                            }
                        }
                    }
                }
                .onTapGesture { showLyrics = false }
            }
        }
    }

    private var currentLineId: UUID? {
        let t = player.currentTime
        // 找到当前时间对应的最后一行
        var current: LyricLine?
        for line in lyrics where line.time <= t {
            current = line
        }
        return current?.id
    }

    // MARK: - Song info
    private var songInfo: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.title ?? "未在播放")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(player.currentTrack?.artist ?? "")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
            Spacer()
            if player.currentTrack?.isOnline == true {
                Button { showComments = true } label: {
                    Image(systemName: "bubble.left")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Progress（iOS 15 兼容的 Slider）
    private var progressBar: some View {
        VStack(spacing: 4) {
            // 自定义进度条：低版本系统可拖动
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: progressWidth(total: geo.size.width), height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .offset(x: progressWidth(total: geo.size.width) - 6)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard player.duration.isFinite, player.duration > 0 else { return }
                            let ratio = min(max(value.location.x / geo.size.width, 0), 1)
                            player.seek(to: ratio * player.duration)
                        }
                )
            }
            .frame(height: 20)
            HStack {
                Text(timeText(player.currentTime))
                    .font(.caption).foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(timeText(player.duration))
                    .font(.caption).foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(.top, 8)
    }

    // 安全时长：防止 duration 为 0、NaN 或无限大导致崩溃
    private var safeDuration: Double {
        if player.duration.isNaN || player.duration.isInfinite || player.duration <= 0 {
            return 1.0
        }
        return player.duration
    }

    private func progressWidth(total: CGFloat) -> CGFloat {
        guard player.duration.isFinite, player.duration > 0 else { return 0 }
        let clampedTime = min(max(player.currentTime, 0), player.duration)
        return total * CGFloat(clampedTime / player.duration)
    }

    // MARK: - Controls
    private var controls: some View {
        HStack(spacing: 36) {
            Button { player.previous() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .disabled(player.isLoadingOnline)

            Button { _ = player.next() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
    }

    // MARK: - Bottom tools
    private var bottomTools: some View {
        HStack(spacing: 32) {
            Button { player.cycleRepeat() } label: {
                Image(systemName: player.repeatMode.iconName)
                    .foregroundColor(player.repeatMode == .off ? .white.opacity(0.5) : .accentColor)
            }
            .buttonStyle(.plain)

            Button { player.setShuffle(!player.isShuffled) } label: {
                Image(systemName: "shuffle")
                    .foregroundColor(player.isShuffled ? .accentColor : .white.opacity(0.5))
            }
            .buttonStyle(.plain)

            Button { player.cycleRate() } label: {
                Text(player.rateText)
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 36)
            }
            .buttonStyle(.plain)

            Button { showLyrics.toggle() } label: {
                Image(systemName: "text.quote")
                    .foregroundColor(showLyrics ? .accentColor : .white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .font(.title3)
        .padding(.top, 4)
    }

    // MARK: - Helpers
    private func timeText(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let total = Int(s)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private func loadLyrics() async {
        lyrics = []
        guard let track = player.currentTrack,
              let sid = track.onlineSongId else { return }
        do {
            lyrics = try await NeteaseAPI.shared.lyrics(for: sid)
        } catch {
            print("歌词加载失败: \(error)")
        }
    }
}

/// 播放器背景：封面高斯模糊
struct PlayerBackground: View {
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var theme: ThemeSettings

    var body: some View {
        ZStack {
            Color.black
            if let data = theme.wallpaperData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
                    .opacity(0.45)
            }
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.55)
        }
    }
}

/// 评论抽屉
struct CommentsSheet: View {
    let songId: Int
    @State private var comments: [SongComment] = []
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                if isLoading {
                    ProgressView().tint(.white)
                } else if comments.isEmpty {
                    Text("暂无评论").foregroundColor(.gray)
                } else {
                    List(comments) { c in
                        HStack(alignment: .top, spacing: 12) {
                            AsyncImageView(url: c.avatarURL, size: 36)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(c.user)
                                        .font(.caption).foregroundColor(.gray)
                                    Spacer()
                                    Text("♥ \(c.likes)")
                                        .font(.caption2).foregroundColor(.gray)
                                }
                                Text(c.content)
                                    .foregroundColor(.white)
                                    .font(.subheadline)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("评论")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            do {
                comments = try await NeteaseAPI.shared.comments(for: songId)
            } catch {
                print("评论加载失败: \(error)")
            }
            isLoading = false
        }
    }
}

/// 播放列队
struct QueueSheet: View {
    @EnvironmentObject private var player: AudioPlayerManager

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                List {
                    ForEach(Array(player.queue.enumerated()), id: \.element.id) { _, track in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(track.title).foregroundColor(.white).lineLimit(1)
                                Text(track.artist).font(.caption).foregroundColor(.gray).lineLimit(1)
                            }
                            Spacer()
                            if track.id == player.currentTrack?.id {
                                Image(systemName: "waveform")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .onTapGesture {
                            player.playTrackInQueue(track)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("播放队列")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
