import Foundation
import AVFoundation
import Combine
import MediaPlayer

/// 音频播放器 - 干净重写版
class AudioPlayerManager: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var isPlaying: Bool = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var queue: [Track] = []
    private var currentIndex: Int = 0
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    func play(_ track: Track) {
        currentTrack = track
        queue = [track]
        currentIndex = 0
        playCurrent()
    }
    
    func playTracks(_ tracks: [Track], startAt index: Int = 0) {
        guard !tracks.isEmpty else { return }
        queue = tracks
        currentIndex = min(index, tracks.count - 1)
        currentTrack = queue[currentIndex]
        playCurrent()
    }
    
    func playOnlineSongs(_ songs: [OnlineSong], startAt index: Int = 0) {
        let tracks = songs.map { song in
            Track(
                title: song.title,
                artist: song.artist,
                album: song.album,
                onlineSongId: song.id
            )
        }
        playTracks(tracks, startAt: index)
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        updateNowPlaying()
    }
    
    func next() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % queue.count
        currentTrack = queue[currentIndex]
        playCurrent()
    }
    
    func previous() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex - 1 + queue.count) % queue.count
        currentTrack = queue[currentIndex]
        playCurrent()
    }
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
        currentTime = seconds
    }
    
    private func playCurrent() {
        guard let track = currentTrack else { return }
        
        // 如果有在线ID，通过API获取播放地址
        if let songId = track.onlineSongId {
            Task {
                await playOnline(songId: songId, track: track)
            }
        } else if let url = track.fileURL {
            playURL(url, track: track)
        }
    }
    
    private func playOnline(songId: Int, track: Track) async {
        // 通过 NeteaseAPI 获取播放地址
        // 这里需要注入 API，暂时用通知方式
        NotificationCenter.default.post(
            name: .playOnlineTrack,
            object: nil,
            userInfo: ["songId": songId, "track": track]
        )
    }
    
    private func playURL(_ url: URL, track: Track) {
        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
            addTimeObserver()
        } else {
            player?.replaceCurrentItem(with: item)
        }
        player?.play()
        isPlaying = true
        duration = track.duration
        updateNowPlaying()
    }
    
    func playURLDirect(_ url: URL, track: Track, duration: Double = 0) {
        playURL(url, track: track)
        if duration > 0 {
            self.duration = duration
        }
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session error: \(error)")
        }
    }
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            if let duration = self?.player?.currentItem?.duration.seconds,
               duration.isFinite {
                self?.duration = duration
            }
        }
    }
    
    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            if self?.isPlaying == false { self?.togglePlayPause() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            if self?.isPlaying == true { self?.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
    }
    
    private func updateNowPlaying() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension Notification.Name {
    static let playOnlineTrack = Notification.Name("playOnlineTrack")
}
