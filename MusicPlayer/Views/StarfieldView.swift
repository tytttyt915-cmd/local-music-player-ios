import SwiftUI

/// 纯黑背景 + 缓慢漂移的星点 + 星云微光
struct StarfieldView: View {
    private struct Star {
        let x: Double     // 0...1
        let y: Double     // 0...1
        let r: Double     // 半径（点）
        let speed: Double // 每秒漂移（归一化）
        let phase: Double
        let twinkle: Double
    }

    @State private var stars: [Star] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                // 星云微光
                let nebula1 = CGRect(x: size.width * 0.1, y: size.height * 0.08,
                                     width: size.width * 0.8, height: size.width * 0.8)
                context.fill(Path(ellipseIn: nebula1), with: .color(.cyan.opacity(0.045)))
                let nebula2 = CGRect(x: size.width * 0.5, y: size.height * 0.5,
                                     width: size.width * 0.9, height: size.width * 0.9)
                context.fill(Path(ellipseIn: nebula2), with: .color(.blue.opacity(0.05)))
                // 星点
                let t = timeline.date.timeIntervalSinceReferenceDate
                for star in stars {
                    let y = (star.y + t * star.speed).truncatingRemainder(dividingBy: 1.0)
                    let tw = 0.35 + 0.65 * abs(sin(t * star.twinkle + star.phase))
                    let rect = CGRect(x: star.x * size.width, y: y * size.height,
                                      width: star.r, height: star.r)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(.white.opacity(0.25 + 0.6 * tw)))
                }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .onAppear {
            if stars.isEmpty { stars = makeStars(count: 170) }
        }
    }

    private func makeStars(count: Int) -> [Star] {
        (0..<count).map { _ in
            Star(
                x: Double.random(in: 0...1),
                y: Double.random(in: 0...1),
                r: Double.random(in: 0.6...2.2),
                speed: Double.random(in: 0.004...0.014),
                phase: Double.random(in: 0...(2 * .pi)),
                twinkle: Double.random(in: 0.6...2.0)
            )
        }
    }
}
