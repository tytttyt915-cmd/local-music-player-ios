import SwiftUI

struct NeteaseLoginView: View {
    @ObservedObject var auth = NeteaseAuthManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var qrKey = ""
    @State private var qrImage: UIImage? = nil
    @State private var statusText = "正在生成二维码..."
    @State private var isExpired = false
    @State private var timer: Timer? = nil
    @State private var showCookieInput = false
    @State private var inputCookie = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if !showCookieInput {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemBackground))
                            .frame(width: 220, height: 220)
                        if let image = qrImage {
                            Image(uiImage: image).resizable().interpolation(.none)
                                .frame(width: 190, height: 190).blur(radius: isExpired ? 4 : 0)
                        } else { ProgressView() }
                        if isExpired {
                            Button { refreshQR() } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise.circle.fill").font(.largeTitle)
                                    Text("点击刷新").font(.caption)
                                }.foregroundColor(.white).padding(12)
                                .background(Color.black.opacity(0.65)).cornerRadius(10)
                            }
                        }
                    }
                    Text(statusText).font(.subheadline).foregroundColor(.secondary)
                    Text("用网易云音乐App扫码登录").font(.caption).foregroundColor(.secondary)
                    Button("用Cookie登录") { showCookieInput = true }.font(.footnote)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("粘贴MUSIC_U Cookie:").font(.subheadline)
                        TextEditor(text: $inputCookie).frame(height: 120)
                            .padding(8).background(Color(.secondarySystemBackground)).cornerRadius(10)
                        Button("登录") {
                            Task {
                                await auth.handleLoginSuccess(cookieStr: inputCookie.trimmingCharacters(in: .whitespacesAndNewlines))
                                dismiss()
                            }
                        }.frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(Color.accentColor).foregroundColor(.white).cornerRadius(10)
                        Button("返回扫码") { showCookieInput = false }.font(.caption).frame(maxWidth: .infinity)
                    }.padding(.horizontal, 24)
                }
                Spacer()
            }.padding(.top, 32)
            .navigationTitle("网易云登录").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                Button("取消") { stopPolling(); dismiss() } } }
            .onAppear { refreshQR() }.onDisappear { stopPolling() }
        }
    }

    private func refreshQR() {
        isExpired = false; qrImage = nil; statusText = "正在生成二维码..."; stopPolling()
        Task {
            do {
                let baseURL = APIConfig.neteaseBase
                let key = try await auth.getQRKey(baseURL: baseURL)
                self.qrKey = key
                if let url = auth.getQRCodeImageURL(baseURL: baseURL, key: key) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let d = json["data"] as? [String: Any],
                       let b64 = d["qrimg"] as? String,
                       let clean = b64.components(separatedBy: ",").last,
                       let imgData = Data(base64Encoded: clean) {
                        await MainActor.run {
                            self.qrImage = UIImage(data: imgData)
                            self.statusText = "等待扫码..."; self.startPolling()
                        }
                    }
                }
            } catch {
                await MainActor.run { self.statusText = "生成失败，请检查网络" }
            }
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                do {
                    let result = try await auth.checkQRStatus(baseURL: APIConfig.neteaseBase, key: qrKey)
                    await MainActor.run {
                        switch result.code {
                        case 800: isExpired = true; statusText = "二维码过期"; stopPolling()
                        case 801: statusText = "等待扫码..."
                        case 802: statusText = "已扫码，请确认"
                        case 803:
                            statusText = "登录成功!"; stopPolling()
                            if let c = result.cookie {
                                Task { await auth.handleLoginSuccess(cookieStr: c); dismiss() }
                            }
                        default: break
                        }
                    }
                } catch { print("轮询出错: \(error)") }
            }
        }
    }

    private func stopPolling() { timer?.invalidate(); timer = nil }
}
