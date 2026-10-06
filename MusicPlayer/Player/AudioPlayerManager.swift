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

/// AVPlayer 封装：播放队列 / 随机 / 循环 / 倍速 / 睡眠定时 / 锁屏线控
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
    /// 睡眠定时剩余秒数，0 表示未开启
    @Published private(set) var sleepRemaining: Int = 0

    // MARK: - Playback order
    /// queue 下标的播放顺序；orderPos 指向当前
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
        guard !order.isEmpty else { return false }
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
        guard !order.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        if orderPos > 0 {
            orderPos -= 1
            playCurrent()
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: Double) {
        guard player != nil else { return }
        let clamped = max(0, seconds)
        player?.seek(to: CMTime(seconds: clamped, preferredTimescale: 600))
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
        player?.replaceCurrentItem(with: nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func playCurrent() {
        guard let track = currentTrack else { return }
        let item = AVPlayerItem(url: track.fileURL)
        if player == nil {
            player = AVPlayer()
            player?.volume = volume
            addTimeObserver()
        }
        player?.replaceCurrentItem(with: item)
        duration = track.duration
        currentTime = 0
        player?.rate = rate
        isPlaying = true
        updateNowPlaying()
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

    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw),
              type == .began
        else { return }
        pause()
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
        if let data = track.artworkData, let image = UIImage(data: data) {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
