import SwiftUI
struct ArtistsView: View {
    @EnvironmentObject var theme: ThemeSettings
    var body: some View {
        Text("ArtistsView")
            .foregroundColor(theme.textColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.backgroundColor.ignoresSafeArea())
    }
}
