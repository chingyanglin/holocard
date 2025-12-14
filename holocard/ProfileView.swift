//
//  ProfileView.swift
//  holocard
//

import SwiftUI
import FirebaseAuth
import PhotosUI

struct ProfileView: View {
    
    @ObservedObject var authVM: AuthViewModel
    @StateObject private var userService = UserService.shared
    
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isEditingName = false
    @State private var displayName = ""
    @State private var notificationsEnabled = false
    @State private var isSaving = false
    
    var onBack: () -> Void
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 頂部導航
                ProfileHeader(onBack: onBack)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // 個人照片 & 名稱
                        ProfileInfoSection(
                            selectedImage: $selectedImage,
                            showImagePicker: $showImagePicker,
                            isEditingName: $isEditingName,
                            displayName: $displayName,
                            memberLevel: userService.userProfile?.memberLevel ?? "Noobie",
                            photoURL: userService.userProfile?.photoURL ?? "",
                            onSaveName: saveName
                        )
                        
                        // 卡片統計
                        CardStatsSection(cardsCreated: userService.userProfile?.cardsCreated ?? 0)
                        
                        // Account Settings
                        AccountSettingsSection(notificationsEnabled: $notificationsEnabled)
                        
                        // More
                        MoreSection(onSignOut: {
                            authVM.signOut()
                        })
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 20)
                }
                
                Spacer(minLength: 0)
                
                // 底部導航
                BottomTabBar(selectedTab: 3, onTabChange: { tab in
                    if tab == 0 {
                        onBack()
                    }
                })
            }
            
            // Loading 狀態
            if userService.isLoading || isSaving {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(Color(hex: "BFFF00"))
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                uploadImage(image)
            }
        }
        .onAppear {
            loadUserProfile()
        }
    }
    
    private func loadUserProfile() {
        guard let userId = authVM.user?.uid else { return }
        userService.fetchUserProfile(userId: userId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let profile = userService.userProfile {
                displayName = profile.displayName.isEmpty ? (authVM.user?.email ?? "User") : profile.displayName
            } else {
                displayName = authVM.user?.email ?? "User"
            }
        }
    }
    
    private func saveName() {
        guard let userId = authVM.user?.uid else { return }
        isSaving = true
        
        userService.updateDisplayName(userId: userId, name: displayName) { success in
            isSaving = false
            if success {
                isEditingName = false
            }
        }
    }
    
    private func uploadImage(_ image: UIImage) {
        guard let userId = authVM.user?.uid else { return }
        
        userService.uploadProfileImage(userId: userId, image: image) { success in
            if !success {
                print("Failed to upload image")
            }
        }
    }
}

// MARK: - 頂部導航
struct ProfileHeader: View {
    var onBack: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(22)
            }
            
            Spacer()
            
            Text("Profile")
                .font(.system(size: 18, weight: .semibold))
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.system(size: 18))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(22)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - 個人資訊
struct ProfileInfoSection: View {
    @Binding var selectedImage: UIImage?
    @Binding var showImagePicker: Bool
    @Binding var isEditingName: Bool
    @Binding var displayName: String
    let memberLevel: String
    let photoURL: String
    var onSaveName: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // 頭像
            ZStack(alignment: .bottomTrailing) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else if !photoURL.isEmpty, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .overlay(ProgressView())
                    }
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))
                        )
                }
                
                Button(action: { showImagePicker = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color(hex: "BFFF00"))
                        .clipShape(Circle())
                }
                .offset(x: 5, y: 5)
            }
            
            // 名稱
            if isEditingName {
                HStack {
                    TextField("輸入暱稱", text: $displayName)
                        .font(.system(size: 24, weight: .bold))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)
                    
                    Button(action: onSaveName) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color(hex: "BFFF00"))
                    }
                }
            } else {
                Button(action: { isEditingName = true }) {
                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // 會員等級
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "BFFF00"))
                
                Text(memberLevel)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - 卡片統計
// MARK: - 卡片統計
struct CardStatsSection: View {
    let cardsCreated: Int
    
    private let cardHeight: CGFloat = 110
    
    var body: some View {
        HStack(spacing: 12) {
            // 左邊卡片
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.08))
                
                HStack(spacing: 0) {
                    // 堆疊卡片
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.purple.opacity(0.6), .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 45, height: 60)
                            .rotationEffect(.degrees(-10))
                            .offset(x: -6)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.pink.opacity(0.6), .orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 45, height: 60)
                            .rotationEffect(.degrees(5))
                            .offset(x: 6)
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(colors: [.cyan.opacity(0.6), .green.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 45, height: 60)
                            .offset(y: -4)
                    }
                    .frame(width: 70)
                    .offset(x: -15)
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trending")
                            .font(.system(size: 18, weight: .bold))
                        Text("Now")
                            .font(.system(size: 18, weight: .bold))
                        Text("from last week")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
            }
            .frame(height: cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            // 右邊卡片
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "BFFF00").opacity(0.3))
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Total Cards Created")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 10) {
                        Text(cardsCreated > 0 ? "\(cardsCreated) cards" : "Start creating")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Button(action: {}) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "BFFF00"))
                                .frame(width: 32, height: 32)
                                .background(Color.black)
                                .cornerRadius(8)
                        }
                    }
                    
                    Text("299 templates")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(14)
            }
            .frame(height: cardHeight)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Account Settings
struct AccountSettingsSection: View {
    @Binding var notificationsEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Account Setting")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "bell")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .frame(width: 32)
                    
                    Text("Notifications")
                        .font(.system(size: 15))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Toggle("", isOn: $notificationsEnabled)
                        .labelsHidden()
                        .tint(Color(hex: "BFFF00"))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                
                Divider().padding(.leading, 72)
                
                SettingsRow(icon: "heart", title: "Wish List")
                
                Divider().padding(.leading, 72)
                
                SettingsRow(icon: "doc.text", title: "Terms & Conditions")
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - More Section
struct MoreSection: View {
    var onSignOut: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("More")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            
            VStack(spacing: 0) {
                SettingsRow(icon: "creditcard", title: "Billing Method")
                
                Divider().padding(.leading, 72)
                
                SettingsRow(icon: "person.badge.plus", title: "Invite Friends")
                
                Divider().padding(.leading, 72)
                
                Button(action: onSignOut) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                            .frame(width: 32)
                        
                        Text("Sign Out")
                            .font(.system(size: 15))
                            .foregroundColor(.red)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }
            }
            .background(Color.gray.opacity(0.05))
            .cornerRadius(16)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - 設定列表項目
struct SettingsRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        Button(action: {}) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .frame(width: 32)
                
                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }
}

// MARK: - 圖片選擇器
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            
            provider.loadObject(ofClass: UIImage.self) { image, _ in
                DispatchQueue.main.async {
                    self.parent.image = image as? UIImage
                }
            }
        }
    }
}

#Preview {
    ProfileView(authVM: AuthViewModel(), onBack: {})
}
