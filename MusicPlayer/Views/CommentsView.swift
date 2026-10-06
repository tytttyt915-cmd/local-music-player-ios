import SwiftUI

/// 评论抽屉：上滑呼出，显示网易云歌曲评论
struct CommentsView: View {
    let songId: Int?
    let songTitle: String

    @State private var comments: [NeteaseComment] = []
    @State private var isLoading = false
    @State private var loadedFor: Int?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                StarfieldView().opacity(0.5)

                Group {
                    if isLoading {
                        VStack {
                            ProgressView().tint(.cyan)
                            Text("评论加载中…").font(.caption).foregroundColor(.gray)
                        }
                    } else if comments.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left")
                                .font(.title).foregroundColor(.gray.opacity(0.6))
                            Text("暂无评论")
                                .font(.subheadline).foregroundColor(.gray)
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(comments) { c in
                                    CommentRow(comment: c)
                                    Divider().background(Color.white.opacity(0.06))
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .navigationTitle("评论 · \(songTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
        }
    }

    private func load() async {
        guard let songId else { return }
        if loadedFor == songId { return }
        isLoading = true
        let list = await NeteaseAPI.comments(for: songId)
        await MainActor.run {
            self.comments = list
            self.loadedFor = songId
            self.isLoading = false
        }
    }
}

private struct CommentRow: View {
    let comment: NeteaseComment

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(colors: [.cyan.opacity(0.5), .blue.opacity(0.5)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .frame(width: 36, height: 36)
                Text(String(comment.nickname.prefix(1)))
                    .font(.subheadline).bold()
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(comment.nickname)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.cyan.opacity(0.9))
                    Spacer()
                    Text(comment.time)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Text(comment.text)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 12)
    }
}
