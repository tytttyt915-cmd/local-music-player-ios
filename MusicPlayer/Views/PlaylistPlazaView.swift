import SwiftUI
struct PlaylistPlazaView: View {
    @EnvironmentObject var theme: ThemeSettings
    var body: some View {
        Text("PlaylistPlazaView")
            .foregroundColor(theme.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.backgroundColor.ignoresSafeArea())
    }
}
