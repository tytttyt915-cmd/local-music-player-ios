import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var theme: ThemeSettings
    @State private var showSettings = false
    @State private var showLogin = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Circle().fill(theme.accentColor).frame(width: 60, height: 60)
                        VStack(alignment: .leading) {
                            Text(profile.nickname).font(.headline)
                            Text(profile.isLoggedIn ? "已登录" : "未登录")
                                .font(.caption).foregroundColor(.gray)
                        }
                    }
                }
                Section {
                    Button("网易云登录") { showLogin = true }
                    Button("设置") { showSettings = true }
                }
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showLogin) { NeteaseLoginView() }
        }
    }
}
