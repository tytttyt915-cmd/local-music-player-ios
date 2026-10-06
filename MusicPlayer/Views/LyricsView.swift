import SwiftUI

/// 歌词面板：加载 LRC、播放时高亮滚动当前行、支持译文
struct LyricsView: View {
    let songId: Int?

    @EnvironmentObject private var player: AudioPlayerManager

    @State private var lines: [LyricLine] = []
    @State private var isLoading = false
    @State private var loadedFor: Int?

    /// 当前行下标
    private var currentIndex: Int {
        let t = player.currentTime
        var idx = -1
        for (i, line) in lines.enumerated() {
            if line.time <= t + 0.2 { idx = i } else { break }
        }
        return idx
    }

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView().tint(.cyan)
                    Text("歌词加载中…").font(.caption).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if lines.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note")
                        .font(.title).foregroundColor(.gray.opacity(0.6))
                    Text("暂无歌词")
                        .font(.subheadline).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            // 顶部留白，让当前行能居中
                            Spacer().frame(height: 120)
                            ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                                LyricRow(line: line, isCurrent: i == currentIndex)
                                    .id(i)
                            }
                            Spacer().frame(height: 200)
                        }
                        .padding(.horizontal, 24)
                    }
                    .onChange(of: currentIndex) { newIndex in
                        guard newIndex >= 0 else { return }
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .task(id: songId) { await load() }
    }

    private func load() async {
        guard let songId else {
            lines = []
            loadedFor = nil
            return
        }
        if loadedFor == songId { return }
        isLoading = true
        let parsed = await NeteaseAPI.lyric(for: songId)
        await MainActor.run {
            self.lines = parsed
            self.loadedFor = songId
            self.isLoading = false
        }
    }
}

private struct LyricRow: View {
    let line: LyricLine
    let isCurrent: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(line.text)
                .font(.system(size: isCurrent ? 20 : 16, weight: isCurrent ? .bold : .regular))
                .foregroundColor(isCurrent ? .white : .gray.opacity(0.75))
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.25), value: isCurrent)
            if let trans = line.translation, !trans.isEmpty {
                Text(trans)
                    .font(.system(size: isCurrent ? 14 : 12))
                    .foregroundColor(isCurrent ? .cyan.opacity(0.9) : .gray.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
