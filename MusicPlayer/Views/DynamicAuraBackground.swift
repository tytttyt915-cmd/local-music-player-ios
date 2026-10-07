import SwiftUI

/// 动态光晕背景：默认深紫+品红双光球呼吸流动
/// iOS 15+，不阻塞主线程
struct DynamicAuraBackground: View {
    @State private var animate = false
    
    // 默认颜色：深紫 #6366f1 + 品红 #ec4899
    private let color1 = Color(red: 0x63/255.0, green: 0x66/255.0, blue: 0xF1/255.0)
    private let color2 = Color(red: 0xEC/255.0, green: 0x48/255.0, blue: 0x99/255.0)
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // 光球1：左上
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [color1.opacity(0.6), color1.opacity(0)]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: animate ? -50 : 50, y: animate ? -30 : 30)
                .blur(radius: 60)
            
            // 光球2：右下
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [color2.opacity(0.5), color2.opacity(0)]),
                        center: .center,
                        startRadius: 10,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: animate ? 40 : -40, y: animate ? 50 : -50)
                .blur(radius: 60)
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 6)
                    .repeatForever(autoreverses: true)
            ) {
                animate.toggle()
            }
        }
    }
}
