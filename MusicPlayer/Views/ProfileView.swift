import SwiftUI
import UniformTypeIdentifiers

/// v3 "我的"页：自定义昵称 + 头像 + 播放统计 + 小彩蛋
struct ProfileView: View {
    @EnvironmentObject private var profile: UserProfile
    @EnvironmentObject private var theme: ThemeSettings
    @EnvironmentObject private var player: AudioPlayerManager
    @EnvironmentObject private var favorites: FavoriteStore

    @State private var showAvatarPicker = false
    @State private var showNicknameEditor = false
    @State private var eggTaps = 0
    @State private var showEgg = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let data = theme.wallpaperData, let img = UIImage(data: data) {
                Image(uiImage: img).resizable().scaledToFill()
                    .ignoresSafeArea().opacity(0.35)
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    profileHeader
                    statsCards
                    menuList
                }
                .padding(.top, 20)
                .padding(.bottom, 140)
            }
        }
        .sheet(isPresented: $showAvatarPicker) {
            ImagePicker { data in
                profile.avatarData = data
            }
        }
        .alert("修改昵称", isPresented: $showNicknameEditor) {
            TextField("昵称", text: $profile.nickname)
            Button("确定", role: .cancel) {}
        }
        .alert("🎉 彩蛋", isPresented: $showEgg) {
            Button("嘿嘿", role: .cancel) {}
        } message: {
            Text("你发现了隐藏彩蛋！音乐与你同在。")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            Button { showAvatarPicker = true } label: {
                Group {
                    if let data = profile.avatarData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(colors: [.pink, .purple],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            )
                    }
                }
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 2))
            }
            .buttonStyle(.plain)

            Button { showNicknameEditor = true } label: {
                HStack(spacing: 6) {
                    Text(profile.nickname)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(.plain)
            // 小彩蛋：连点头像 7 次
            .onTapGesture(count: 1) {
                eggTaps += 1
                if eggTaps >= 7 {
                    showEgg = true
                    eggTaps = 0
                }
            }
        }
    }

    private var statsCards: some View {
        HStack(spacing: 14) {
            statCard(title: "总播放", value: "\(player.stats.totalPlays)", icon: "play.circle")
            statCard(title: "听歌时长", value: player.stats.listeningTimeText, icon: "clock")
            statCard(title: "收藏", value: "\(favorites.ids.count)", icon: "heart")
        }
        .padding(.horizontal, 20)
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text(value)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
        )
    }

    private var menuList: some View {
        VStack(spacing: 2) {
            menuRow(icon: "heart.fill", title: "我的收藏") {}
            menuRow(icon: "clock.fill", title: "最近播放") {}
            menuRow(icon: "square.and.arrow.down.fill", title: "本地缓存管理") {}
            menuRow(icon: "gearshape.fill", title: "设置") {}
        }
        .padding(.horizontal, 20)
    }

    private func menuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                    .frame(width: 28)
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }
}

/// 图片选择器
struct ImagePicker: UIViewControllerRepresentable {
    let onPick: (Data?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (Data?) -> Void
        init(onPick: @escaping (Data?) -> Void) { self.onPick = onPick }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onPick(image.jpegData(compressionQuality: 0.8))
            } else {
                onPick(nil)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onPick(nil)
        }
    }
}
