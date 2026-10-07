import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var theme: ThemeSettings
    var body: some View {
        NavigationView {
            Form {
                Section("主题") {
                    Picker("强调色", selection: $theme.accent) {
                        ForEach(ThemeSettings.AccentChoice.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    Toggle("深色模式", isOn: $theme.darkMode)
                }
            }
            .navigationTitle("设置")
        }
    }
}
