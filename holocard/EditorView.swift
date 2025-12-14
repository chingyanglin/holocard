//
//  EditorView.swift
//  holocard
//

import SwiftUI
import PhotosUI
import FirebaseStorage

struct EditorView: View {
    
    var onBack: () -> Void
    
    @State private var currentPage = 0
    @State private var selectedImage: UIImage? = nil
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    @State private var uploadedImageURL: String? = nil
    
    // 圖片位置偏移
    @State private var imageOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // 圖片縮放
    @State private var imageScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // 背景 - 淺灰色
            Color(hex: "F5F5F5").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 頂部導航
                EditorHeader(onBack: onBack)
                
                Spacer()
                
                // 預覽區域
                EditorPreview(
                    selectedImage: selectedImage,
                    imageOffset: $imageOffset,
                    lastOffset: $lastOffset,
                    imageScale: $imageScale,
                    lastScale: $lastScale
                )
                
                Spacer()
                
                // 頁面縮略圖
                EditorPageThumbnails(
                    currentPage: $currentPage,
                    selectedImage: selectedImage,
                    selectedItem: $selectedItem,
                    onImageSelected: loadImage
                )
                
                // 底部工具欄
                EditorToolbar(
                    selectedItem: $selectedItem,
                    onImageSelected: loadImage,
                    isUploading: isUploading
                )
            }
            
            // 上傳中的 Loading
            if isUploading {
                Color.black.opacity(0.4).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("上傳中...")
                        .foregroundColor(.white)
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(30)
                .background(Color.black.opacity(0.7))
                .cornerRadius(16)
            }
        }
    }
    
    // 載入選擇的圖片
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        self.selectedImage = image
                        // 重置位置和縮放
                        self.imageOffset = .zero
                        self.lastOffset = .zero
                        self.imageScale = 1.0
                        self.lastScale = 1.0
                        // 上傳到 Firebase
                        uploadImageToFirebase(image: image)
                    }
                case .failure(let error):
                    print("Error loading image: \(error)")
                }
            }
        }
    }
    
    // 上傳圖片到 Firebase Storage
    private func uploadImageToFirebase(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        isUploading = true
        
        let storageRef = Storage.storage().reference()
        let imageRef = storageRef.child("cards/\(UUID().uuidString).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                print("Upload error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    isUploading = false
                }
                return
            }
            
            imageRef.downloadURL { url, error in
                DispatchQueue.main.async {
                    isUploading = false
                    if let url = url {
                        uploadedImageURL = url.absoluteString
                        print("Image uploaded: \(url.absoluteString)")
                    }
                }
            }
        }
    }
}


// MARK: - 頂部導航
struct EditorHeader: View {
    var onBack: () -> Void
    
    var body: some View {
        HStack {
            // 首頁按鈕
            Button(action: onBack) {
                Image(systemName: "house.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            // 右側工具
            HStack(spacing: 20) {
                // Undo
                Button(action: {}) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.6))
                }
                
                // Redo
                Button(action: {}) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16))
                        .foregroundColor(.black.opacity(0.6))
                }
                
                // 儲存草稿
                Button(action: {}) {
                    Image(systemName: "opticaldiscdrive.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.black)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(hex: "BFFF00"))
    }
}

// MARK: - 預覽區域
struct EditorPreview: View {
    var selectedImage: UIImage?
    @Binding var imageOffset: CGSize
    @Binding var lastOffset: CGSize
    @Binding var imageScale: CGFloat
    @Binding var lastScale: CGFloat
    
    var body: some View {
        // 卡片預覽
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.1))
            
            // 背景圖片或漸層
            if let image = selectedImage {
                // 使用者選擇的圖片 - 可拖曳移動
                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(imageScale)
                        .offset(imageOffset)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    imageOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = imageOffset
                                }
                        )
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    imageScale *= delta
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    // 限制縮放範圍
                                    if imageScale < 0.5 {
                                        withAnimation {
                                            imageScale = 0.5
                                        }
                                    } else if imageScale > 3.0 {
                                        withAnimation {
                                            imageScale = 3.0
                                        }
                                    }
                                }
                        )
                }
            } else {
                // 預設漸層背景
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.7),
                        Color.blue.opacity(0.5),
                        Color.pink.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            
            // 卡片內容 overlay
            VStack {
                // 頂部：評分 & 愛心
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                        Text("5.0")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(14)
                    
                    Spacer()
                    
                    Image(systemName: "heart")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(14)
                }
                .padding(20)
                
                Spacer()
                
                // 底部：標題 & 箭頭
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Midnight Glow")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Holographic effects with deep blue shimmer")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color(hex: "BFFF00"))
                        .cornerRadius(12)
                }
                .padding(20)
            }
            
            // 拖曳提示（有圖片時顯示）
            if selectedImage != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "hand.draw")
                                .font(.system(size: 10))
                            Text("拖曳調整位置")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(8)
                        .padding(8)
                    }
                }
            }
        }
        .frame(width: 340, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
}

// MARK: - 頁面縮略圖
struct EditorPageThumbnails: View {
    @Binding var currentPage: Int
    var selectedImage: UIImage?
    @Binding var selectedItem: PhotosPickerItem?
    var onImageSelected: (PhotosPickerItem?) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 當前頁面縮略圖
            ZStack(alignment: .bottomLeading) {
                if let image = selectedImage {
                    // 顯示選擇的圖片
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "BFFF00"), lineWidth: 2)
                        )
                } else {
                    // 預設漸層
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(hex: "BFFF00"), lineWidth: 2)
                        )
                }
                
                // 編輯圖示
                Image(systemName: "pencil")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .offset(x: 4, y: -4)
            }
            
            // 新增媒體按鈕 - PhotosPicker
            PhotosPicker(
                selection: $selectedItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.gray)
                    .frame(width: 50, height: 70)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .onChange(of: selectedItem) { _, newValue in
                onImageSelected(newValue)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}

// MARK: - 底部工具欄
struct EditorToolbar: View {
    @State private var selectedTool = 0
    @Binding var selectedItem: PhotosPickerItem?
    var onImageSelected: (PhotosPickerItem?) -> Void
    var isUploading: Bool
    
    let tools = [
        ("square.grid.2x2", "設計"),
        ("square.on.square", "元素"),
        ("textformat", "文字"),
        ("camera.viewfinder", "相機膠卷"),
        ("briefcase.fill", "品牌"),
        ("icloud.and.arrow.up", "上傳"),
        ("wrench.and.screwdriver", "工具")
    ]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(0..<tools.count, id: \.self) { index in
                    // 上傳按鈕特殊處理
                    if index == 5 {
                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .images,
                            photoLibrary: .shared()
                        ) {
                            VStack(spacing: 4) {
                                Image(systemName: tools[index].0)
                                    .font(.system(size: 18))
                                    .foregroundColor(selectedTool == index ? Color(hex: "7CB342") : .gray)
                                
                                Text(tools[index].1)
                                    .font(.system(size: 9))
                                    .foregroundColor(selectedTool == index ? Color(hex: "7CB342") : .gray)
                            }
                            .frame(width: 60, height: 50)
                        }
                        .onChange(of: selectedItem) { _, newValue in
                            selectedTool = index
                            onImageSelected(newValue)
                        }
                        .disabled(isUploading)
                    } else {
                        Button(action: {
                            selectedTool = index
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: tools[index].0)
                                    .font(.system(size: 18))
                                    .foregroundColor(selectedTool == index ? Color(hex: "7CB342") : .gray)
                                
                                Text(tools[index].1)
                                    .font(.system(size: 9))
                                    .foregroundColor(selectedTool == index ? Color(hex: "7CB342") : .gray)
                            }
                            .frame(width: 60, height: 50)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
        }
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

#Preview {
    EditorView(onBack: {})
}
