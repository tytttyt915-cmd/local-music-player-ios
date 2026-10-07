import AVFoundation
import MediaPlayer
import Combine
import UIKit

enum RepeatMode: String, CaseIterable {
    case off, all, one

    var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

/// AVPlayer 封装：本地 + 在线播放 / 队列 / 随机 / 循环 / 倍速 / 睡眠定时 / 锁屏线控 / 灵动岛
/// v3: 支持在线 URL（失败自动换源）、播放统计、音频打断自动恢复
@MainActor
final class AudioPlayerManager: ObservableObject {
    // MARK: - Published state
    @Published private(set) var queue: [Track] = []
    @Published private(set) var isPlaying = false
    @Published var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var volume: Float = 0.8 {
        didSet { player?.volume = volume }
    }
    @Published private(set) var rate: Float = 1.0
    @Published private(set) var isShuffled = false
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var sleepRemaining: Int = 0
    /// 当前在线播放 URL（在线歌曲）
    @Published private(set) var isLoadingOnline = false
    @Published private(set) var loadingSongId: String?
    @Published private(set) var onlineError: String?
    @Published var showErrorAlert = false

    /// 设置在线播放错误并弹窗提示
    func reportOnlineError(_ message: String) {
        onlineError = message
        showErrorAlert = true
    }

    func clearOnlineError() {
        onlineError = nil
        showErrorAlert = false
        loadingSongId = nil
    }

    var stats = PlaybackStats()

    // MARK: - Playback order
    private var order: [Int] = []
    private var orderPos: Int = 0

    var currentTrack: Track? {
        guard !order.isEmpty, orderPos < order.count else { return nil }
        let qi = order[orderPos]
        guard queue.indices.contains(qi) else { return nil }
        return queue[qi]
    }

    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var sleepTimer: Timer?
    private var sleepEndDate: Date?
    private let rates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    private var wasPlayingBeforeInterruption = false
    private var onlineArtworkCache: [String: UIImage] = [:]

    init() {
        setupAudioSession()
        setupRemoteCommands()
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleTrackEnded() }
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: nil, queue: .main
        ) { [weak self] _ in
            // v3: 播放失败立即切下一首（无 10 秒等待）
            Task { @MainActor in _ = self?.next() }
        }
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        }
    }

    // MARK: - Queue control
    func play(tracks: [Track], startAt index: Int) {
        guard !tracks.isEmpty, tracks.indices.contains(index) else { return }
        queue = tracks
        buildOrder(currentQueueIndex: index)
        playCurrent()
    }

    func playTrackInQueue(_ track: Track) {
        if let i = queue.firstIndex(of: track) {
            buildOrder(currentQueueIndex: i)
            playCurrent()
        }
    }

    /// 快捷：播放单首在线歌曲
    func playOnline(_ song: OnlineSong) {
        play(tracks: [Track(online: song)], startAt: 0)
    }

    /// 快捷：播放在线歌单
    func playOnlineSongs(_ songs: [OnlineSong], startAt index: Int = 0) {
        play(tracks: songs.map(Track.init(online:)), startAt: index)
    }

    func removeFromQueue(at queueIndex: Int) {
        guard queue.indices.contains(queueIndex) else { return }
        let currentQueueIndex = currentTrack.flatMap { queue.firstIndex(of: $0) }
        let wasCurrent = currentQueueIndex == queueIndex
        queue.remove(at: queueIndex)
        guard !queue.isEmpty else { stop(); return }
        if wasCurrent {
            let nextIndex = min(queueIndex, queue.count - 1)
            buildOrder(currentQueueIndex: nextIndex)
            playCurrent()
        } else if let cur = currentQueueIndex {
            buildOrder(currentQueueIndex: min(cur, queue.count - 1))
        } else {
            buildOrder(currentQueueIndex: 0)
        }
    }

    func clearQueue() { stop() }

    // MARK: - Transport
    func togglePlayPause() {
        if isPlaying { pause() } else { resume() }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlaying()
    }

    @discardableResult
    func next() -> Bool {
        guard !queue.isEmpty, !order.isEmpty else { return false }
        // 校验映射表指针有效性，防止越界崩溃
        guard order.indices.contains(orderPos) else {
            resetOrder()
            if order.indices.contains(orderPos) {
                playCurrent()
                return true
            }
            return false
        }
        if orderPos + 1 < order.count {
            orderPos += 1
            playCurrent()
            return true
        } else if repeatMode == .all {
            orderPos = 0
            playCurrent()
            return true
        }
        return false
    }

    func previous() {
        guard !queue.isEmpty, !order.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        // 校验映射表指针有效性
        guard order.indices.contains(orderPos) else {
            resetOrder()
            return
        }
        if orderPos > 0 {
            orderPos -= 1
            playCurrent()
        } else if repeatMode == .all, !order.isEmpty {
            orderPos = order.count - 1
            playCurrent()
        } else {
            seek(to: 0)
        }
    }

    // 重置播放顺序映射表（越界保护）
    private func resetOrder() {
        guard !queue.isEmpty else {
            order = []
            orderPos = 0
            return
        }
        order = Array(0..<queue.count)
        if isShuffled {
            order.shuffle()
        }
        orderPos = 0
    }

    func seek(to seconds: Double) {
        guard player != nil else { return }
        let clamped = max(0, seconds)
        // iOS 15 兼容：使用精确 seek
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                     toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        updateNowPlaying()
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    func setShuffle(_ on: Bool) {
        guard on != isShuffled else { return }
        isShuffled = on
        let cur = currentTrack.flatMap { queue.firstIndex(of: $0) } ?? 0
        buildOrder(currentQueueIndex: cur)
    }

    func cycleRate() {
        if let i = rates.firstIndex(of: rate), i + 1 < rates.count {
            rate = rates[i + 1]
        } else {
            rate = rates[0]
        }
        if isPlaying { player?.rate = rate }
        updateNowPlaying()
    }

    var rateText: String {
        rate.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(rate))x" : "\(rate)x"
    }

    // MARK: - Sleep timer
    func startSleepTimer(minutes: Int) {
        cancelSleepTimer()
        guard minutes > 0 else { return }
        sleepEndDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepRemaining = minutes * 60
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickSleepTimer() }
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepEndDate = nil
        sleepRemaining = 0
    }

    var sleepText: String {
        guard sleepRemaining > 0 else { return "睡眠定时" }
        return "还剩 \(sleepRemaining / 60) 分钟"
    }

    // MARK: - Private playback
    private func resume() {
        guard player != nil else { return }
        player?.rate = rate
        isPlaying = true
        updateNowPlaying()
    }

    private func stop() {
        pause()
        queue = []
        order = []
        orderPos = 0
        currentTime = 0
        duration = 0
        onlineError = nil
        player?.replaceCurrentItem(with: nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func playCurrent() {
        guard let track = currentTrack else { return }
        onlineError = nil

        if track.isOnline {
            playOnlineTrack(track)
        } else {
            playLocalTrack(track)
        }
    }

    private func playLocalTrack(_ track: Track) {
        let item = AVPlayerItem(url: track.fileURL)
        startItem(item, track: track)
        stats.recordPlay(duration: track.duration)
    }

    private func playOnlineTrack(_ track: Track) {
        guard case .online(let songId, let source) = track.kind else { return }
        isLoadingOnline = true
        let song = OnlineSong(id: songId, title: track.title, artist: track.artist,
                              album: track.album, albumId: 0, artworkURL: track.artworkURL,
                              duration: track.duration, source: source)
        Task {
            do {
                let url = try await NeteaseAPI.shared.songURL(for: song)
                let item = AVPlayerItem(url: url)
                self.startItem(item, track: track)
                self.isLoadingOnline = false
                self.stats.recordPlay(duration: track.duration)
                // 预加载封面
                self.prefetchArtwork(for: track)
            } catch {
                self.isLoadingOnline = false
                // v3: 无版权/失败时明确提示，不静默
                self.onlineError = "无法播放（可能无版权），已跳过"
                // 立即切下一首
                _ = self.next()
            }
        }
    }

    private func startItem(_ item: AVPlayerItem, track: Track) {
        if player == nil {
            player = AVPlayer()
            player?.volume = volume
            addTimeObserver()
        }
        player?.replaceCurrentItem(with: item)
        duration = track.duration > 0 ? track.duration : duration
        currentTime = 0
        player?.rate = rate
        isPlaying = true
        updateNowPlaying()
    }

    private func prefetchArtwork(for track: Track) {
        guard let url = track.artworkURL else { return }
        let key = url.absoluteString
        guard onlineArtworkCache[key] == nil else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                self.onlineArtworkCache[key] = image
                self.updateNowPlaying()
            }
        }
    }

    private func buildOrder(currentQueueIndex: Int) {
        guard !queue.isEmpty else {
            order = []
            orderPos = 0
            return
        }
        let safe = min(max(currentQueueIndex, 0), queue.count - 1)
        if isShuffled {
            var rest = Array(queue.indices)
            rest.removeAll { $0 == safe }
            rest.shuffle()
            order = [safe] + rest
            orderPos = 0
        } else {
            order = Array(queue.indices)
            orderPos = safe
        }
    }

    private func handleTrackEnded() {
        if repeatMode == .one {
            seek(to: 0)
            resume()
            return
        }
        if !next() {
            isPlaying = false
            seek(to: 0)
            updateNowPlaying()
        }
    }

    /// v3: 音频被其他应用打断后自动恢复播放
    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw)
        else { return }
        if type == .began {
            wasPlayingBeforeInterruption = isPlaying
            pause()
        } else if type == .ended {
            let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt).map {
                AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume)
            } ?? false
            if shouldResume || wasPlayingBeforeInterruption {
                resume()
            }
            wasPlayingBeforeInterruption = false
        }
    }

    private func tickSleepTimer() {
        guard let end = sleepEndDate else { return }
        let remain = Int(end.timeIntervalSinceNow)
        if remain <= 0 {
            pause()
            cancelSleepTimer()
        } else {
            sleepRemaining = remain
        }
    }

    private func addTimeObserver() {
        guard timeObserver == nil else { return }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                let s = time.seconds
                if s.isFinite { self.currentTime = s }
                if let d = self.player?.currentItem?.duration.seconds, d.isFinite, d > 0 {
                    self.duration = d
                }
                self.updateNowPlaying()
            }
        }
    }

    // MARK: - Audio session & remote commands
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }

    private func setupRemoteCommands() {
        let cc = MPRemoteCommandCenter.shared()

        cc.playCommand.isEnabled = true
        cc.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        cc.pauseCommand.isEnabled = true
        cc.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        cc.togglePlayPauseCommand.isEnabled = true
        cc.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }
        cc.nextTrackCommand.isEnabled = true
        cc.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in _ = self?.next() }
            return .success
        }
        cc.previousTrackCommand.isEnabled = true
        cc.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        cc.changePlaybackPositionCommand.isEnabled = true
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(to: e.positionTime) }
            return .success
        }
    }

    private func updateNowPlaying() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0.0
        ]
        // 封面：自定义 > 本地内嵌 > 在线缓存
        var artworkImage: UIImage?
        if let data = track.displayArtworkData {
            artworkImage = UIImage(data: data)
        } else if let url = track.artworkURL,
                  let cached = onlineArtworkCache[url.absoluteString] {
            artworkImage = cached
        }
        if let image = artworkImage {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
