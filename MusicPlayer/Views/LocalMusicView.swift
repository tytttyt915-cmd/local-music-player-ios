import SwiftUI
struct LocalMusicView: View {
    @EnvironmentObject var theme: ThemeSettings
    var body: some View {
        Text("LocalMusicView")
            .foregroundColor(theme.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.backgroundColor.ignoresSafeArea())
    }
}
