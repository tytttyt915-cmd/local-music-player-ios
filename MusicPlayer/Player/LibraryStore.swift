import Foundation
import Combine

/// 本地曲库：扫描并管理 Documents 下的音频文件。
@MainActor
final class LibraryStore: ObservableObject {
    static let documentsDirectory: URL = {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }()

    @Published private(set) var tracks: [Track] = []
    @Published private(set) var isLoading = false

    private let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "wave", "aiff", "aif",
        "flac", "mp4", "m4v"
    ]

    init() {
        refresh()
    }

    func refresh() {
        Task { await loadTracks() }
    }

    private func loadTracks() async {
        isLoading = true
        defer { isLoading = false }

        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(
                at: Self.documentsDirectory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            files = []
        }

        let audioFiles = files
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }

        var result: [Track] = []
        for url in audioFiles {
            let meta = await Task.detached { MetadataReader.read(from: url) }.value
            result.append(Track(
                id: url.lastPathComponent,
                title: meta.title,
                artist: meta.artist,
                album: meta.album,
                duration: meta.duration,
                artworkData: meta.artwork
            ))
        }
        tracks = result
    }

    /// 从文件选择器导入：拷贝进 App 沙盒 Documents。
    func importFiles(_ urls: [URL]) async {
        for url in urls {
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer {
                if needsAccess { url.stopAccessingSecurityScopedResource() }
            }
            let dest = Self.documentsDirectory.appendingPathComponent(uniqueFileName(for: url.lastPathComponent))
            do {
                try FileManager.default.copyItem(at: url, to: dest)
            } catch {
                continue
            }
        }
        await loadTracks()
    }

    func delete(_ track: Track) {
        try? FileManager.default.removeItem(at: track.fileURL)
        tracks.removeAll { $0.id == track.id }
    }

    private func uniqueFileName(for name: String) -> String {
        var candidate = name
        var n = 1
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        while FileManager.default.fileExists(
            atPath: Self.documentsDirectory.appendingPathComponent(candidate).path
        ) {
            candidate = ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)"
            n += 1
        }
        return candidate
    }
}
