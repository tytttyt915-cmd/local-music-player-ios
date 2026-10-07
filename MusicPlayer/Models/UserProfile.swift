import SwiftUI
import Combine

/// 用户资料
class UserProfile: ObservableObject {
    @Published var nickname: String = "SØND 用户"
    @Published var avatarURL: String? = nil
    @Published var isLoggedIn: Bool = false
}
