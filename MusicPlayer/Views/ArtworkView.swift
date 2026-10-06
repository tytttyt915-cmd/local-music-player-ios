import SwiftUI
import UIKit

/// 封面：有内嵌图用内嵌图，否则用几何占位图
struct ArtworkView: View {
    let track: Track

    var body: some View {
        Group {
            if let data = track.artworkData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                GeometricPlaceholder(seed: track.id)
            }
        }
        .clipped()
    }
}

/// 无封面时的黑白霓虹几何占位图（按 track id 确定性变化）
struct GeometricPlaceholder: View {
    let seed: String

    private var variant: Int { abs(seed.hashValue) % 4 }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.cyan.opacity(0.28), Color.blue.opacity(0.42)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            switch variant {
            case 0:
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    .scaleEffect(0.62)
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .scaleEffect(0.12)
            case 1:
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white.opacity(0.45), lineWidth: 2)
                    .scaleEffect(0.55)
                    .rotationEffect(.degrees(45))
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .scaleEffect(0.12)
            case 2:
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                        .scaleEffect(0.35 + CGFloat(i) * 0.2)
                }
            default:
                Image(systemName: "music.note")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .background(Color(white: 0.09))
    }
}
