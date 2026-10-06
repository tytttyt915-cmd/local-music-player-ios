import Foundation
import Combine

/// 收藏（红心）：把 track id 集合持久化到 Documents/favorites.json。
/// 说明：未使用 SwiftData——SwiftData 要求 iOS 17+，与本工程 Deployment Target 16.0 冲突，
/// 用 JSON 文件达到同样的持久化效果。
@MainActor
final class FavoriteStore: ObservableObject {
    @Published private(set) var ids: Set<String> = []

    private var fileURL: URL {
        LibraryStore.documentsDirectory.appendingPathComponent("favorites.json")
    }

    init() { load() }

    func isFavorite(_ track: Track) -> Bool { ids.contains(track.id) }

    func toggle(_ track: Track) {
        if ids.contains(track.id) {
            ids.remove(track.id)
        } else {
            ids.insert(track.id)
        }
        save()
    }

    func remove(id: String) {
        if ids.remove(id) != nil { save() }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let arr = try? JSONDecoder().decode([String].self, from: data)
        else { return }
        ids = Set(arr)
    }

    private func save() {
        try? JSONEncoder().encode(Array(ids)).write(to: fileURL, options: .atomic)
    }
}
