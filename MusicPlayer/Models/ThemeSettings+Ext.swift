import SwiftUI

extension ThemeSettings {
    var accentColor: Color {
        switch accent {
        case .coral: return Color(red: 1.0, green: 0.4, blue: 0.4)
        case .violet: return Color(red: 0.6, green: 0.4, blue: 1.0)
        case .azure: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .mint: return Color(red: 0.3, green: 0.9, blue: 0.7)
        case .amber: return Color(red: 1.0, green: 0.7, blue: 0.2)
        }
    }
    var backgroundColor: Color { .black }
    var textColor: Color { .white }
    var secondaryTextColor: Color { .gray }
}
