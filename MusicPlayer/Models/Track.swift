import Foundation

/// 单条本地音频。id 为 Documents 下的文件名，全局稳定唯一。
struct Track: Identifiable, Hashable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let duration: Double
    let artworkData: Data?

    var fileURL: URL {
        LibraryStore.documentsDirectory.appendingPathComponent(id)
    }

    var durationText: String {
        guard duration.isFinite, duration > 0 else { return "--:--" }
        let total = Int(duration)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func == (lhs: Track, rhs: Track) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
