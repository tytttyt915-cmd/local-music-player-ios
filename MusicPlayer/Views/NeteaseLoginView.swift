import SwiftUI

struct NeteaseLoginView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationView {
            Text("网易云登录（待实现）")
                .navigationTitle("登录")
                .toolbar {
                    Button("关闭") { dismiss() }
                }
        }
    }
}
