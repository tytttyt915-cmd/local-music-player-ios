import SwiftUI
import UniformTypeIdentifiers

/// v3 设置页：账号 / 音源 / 音质 / 外观 / 播放器
struct SettingsView: View {
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var api: NeteaseAPI
    @EnvironmentObject private var profile: UserProfile

    @State private var showWallpaperPicker = false
    @State private var dailyRecOldStyle = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            List {
                // 账号
                Section("账号") {
                    HStack {
                        Text("昵称")
                        Spacer()
                        Text(profile.nickname)
                            .foregroundColor(.gray)
                    }
                    Button("退出登录") {}
                        .foregroundColor(.red)
                }

                // 音源
                Section("音源与播放") {
                    Picker("播放来源", selection: $api.sourcePolicy) {
                        ForEach(PlaySourcePolicy.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    Picker("Wi-Fi 音质", selection: $api.wifiQuality) {
                        ForEach(AudioQuality.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    Picker("蜂窝网络音质", selection: $api.cellularQuality) {
                        ForEach(AudioQuality.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    Toggle("播放失败自动换源", isOn: .constant(true))
                        .disabled(true)
                }

                // 外观
                Section("外观") {
                    Picker("强调色", selection: $theme.accent) {
                        ForEach(ThemeSettings.AccentChoice.allCases) { a in
                            Text(a.rawValue).tag(a)
                        }
                    }
                    Picker("底栏样式", selection: $theme.tabBarStyle) {
                        ForEach(ThemeSettings.TabBarStyle.allCases) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    Toggle("隐藏底栏", isOn: $theme.tabBarHidden)
                    Toggle("液态玻璃效果", isOn: $theme.liquidEffectEnabled)
                    Button("自定义壁纸") {
                        showWallpaperPicker = true
                    }
                    if theme.wallpaperData != nil {
                        Button("清除壁纸") {
                            theme.wallpaperData = nil
                        }
                        .foregroundColor(.red)
                    }
                }

                // 播放器
                Section("播放器") {
                    Toggle("灵动岛 / 控制中心显示", isOn: $theme.showDynamicIsland)
                    Toggle("每日推荐旧版样式", isOn: $dailyRecOldStyle)
                }

                // 关于
                Section("关于") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("3.0").foregroundColor(.gray)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWallpaperPicker) {
            ImagePicker { data in
                theme.wallpaperData = data
            }
        }
    }
}
