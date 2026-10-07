import SwiftUI

/// 2.0 旗舰级动态流光背景：根据封面主色调呼吸流动
struct DynamicAuraBackground: View {
    let artworkImage: UIImage?
    @State private var animateGlow: Bool = false

    var body: some View {
        ZStack {
            Color.black
            if let image = artworkImage {
                let mainColor = Color(uiColor: image.dominantColor)
                GeometryReader { geo in
                    ZStack {
                        Circle()
                            .fill(mainColor.opacity(0.45))
                            .frame(width: geo.size.width * 0.9)
                            .blur(radius: 70)
                            .offset(x: animateGlow ? -30 : 40, y: animateGlow ? -60 : 30)
                        Circle()
                            .fill(mainColor.opacity(0.35))
                            .frame(width: geo.size.width * 0.8)
                            .blur(radius: 60)
                            .offset(x: animateGlow ? 40 : -20, y: animateGlow ? 60 : -40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                        animateGlow.toggle()
                    }
                }
            }
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.85)
        }
        .ignoresSafeArea()
    }
}

extension UIImage {
    var dominantColor: UIColor {
        guard let inputImage = CIImage(image: self) else { return .purple }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]),
              let outputImage = filter.outputImage else { return .purple }
        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return UIColor(red: CGFloat(bitmap[0])/255, green: CGFloat(bitmap[1])/255, blue: CGFloat(bitmap[2])/255, alpha: 1)
    }
}
