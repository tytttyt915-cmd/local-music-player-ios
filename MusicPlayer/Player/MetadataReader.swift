import AVFoundation
import Foundation

struct TrackMetadata {
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let artwork: Data?
}

enum MetadataReader {
    /// 同步读取 AVAsset 属性，必须在后台线程调用。
    static func read(from url: URL) -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        let seconds = CMTimeGetSeconds(asset.duration)
        let duration = seconds.isFinite ? max(seconds, 0) : 0

        var title: String?
        var artist: String?
        var album: String?
        var artwork: Data?

        for item in asset.commonMetadata {
            guard let key = item.commonKey?.rawValue else { continue }
            switch key {
            case AVMetadataKey.commonKeyTitle.rawValue:
                if let v = item.stringValue, !v.isEmpty { title = v }
            case AVMetadataKey.commonKeyArtist.rawValue:
                if let v = item.stringValue, !v.isEmpty { artist = v }
            case AVMetadataKey.commonKeyAlbumName.rawValue:
                if let v = item.stringValue, !v.isEmpty { album = v }
            case AVMetadataKey.commonKeyArtwork.rawValue:
                if let v = item.dataValue { artwork = v }
            default:
                break
            }
        }

        let fallback = url.deletingPathExtension().lastPathComponent
        return TrackMetadata(
            title: title ?? fallback,
            artist: artist ?? "未知艺人",
            album: album ?? "未知专辑",
            duration: duration,
            artwork: artwork
        )
    }
}
