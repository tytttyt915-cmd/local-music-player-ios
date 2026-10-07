import SwiftUI
import Combine

/// 主题设置（参考 Beans ThemeStore）
class ThemeSettings: ObservableObject {
    @Published var accent: AccentChoice = .blue
    @Published var darkMode: Bool = true
    
    enum AccentChoice: String, CaseIterable {
        case blue = "星蓝"
        case purple = "罗兰紫"
        case pink = "樱粉"
        case green = "青碧"
        case orange = "琥珀"
        case red = "蜜桃粉"
        
        var color: Color {
            switch self {
            case .blue: return Color(red: 0.2, green: 0.5, blue: 1.0)
            case .purple: return Color(red: 0.6, green: 0.4, blue: 1.0)
            case .pink: return Color(red: 1.0, green: 0.4, blue: 0.7)
            case .green: return Color(red: 0.2, green: 0.8, blue: 0.6)
            case .orange: return Color(red: 1.0, green: 0.6, blue: 0.2)
            case .red: return Color(red: 1.0, green: 0.3, blue: 0.3)
            }
        }
    }
    
    var accentColor: Color { accent.color }
    var backgroundColor: Color { darkMode ? .black : .white }
    var textColor: Color { darkMode ? .white : .black }
    var secondaryTextColor: Color { darkMode ? .gray : .secondary }
}
