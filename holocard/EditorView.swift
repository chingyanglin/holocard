//
//  EditorView.swift
//  holocard
//

import SwiftUI
import PhotosUI
import FirebaseStorage
import CoreMotion
import Combine

// MARK: - 陀螺儀管理器
class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    @Published var pitch: Double = 0  // 前後傾斜
    @Published var roll: Double = 0   // 左右傾斜
    @Published var isActive: Bool = false  // 是否啟用
    
    // 校正基準點（手機正常握持時的角度）
    private var calibratedPitch: Double = 0
    private var calibratedRoll: Double = 0
    private var calibrationCount = 0  // 校正計數器
    private var isCalibrated = false
    
    init() {
        // 不自動啟動，等用戶選擇閃卡效果後才啟動
    }
    
    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard !isActive else { return }  // 避免重複啟動
        
        isActive = true
        isCalibrated = false
        calibrationCount = 0
        calibratedPitch = 0
        calibratedRoll = 0
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main) { [weak self] motion, error in
            guard let self = self, let motion = motion, error == nil else { return }
            
            let rawPitch = motion.attitude.pitch * 180.0 / Double.pi
            let rawRoll = motion.attitude.roll * 180.0 / Double.pi
            
            // 前 10 次讀數用來校正（取平均值）
            if self.calibrationCount < 10 {
                self.calibratedPitch += rawPitch
                self.calibratedRoll += rawRoll
                self.calibrationCount += 1
                return  // 校正期間不更新顯示
            }
            
            // 完成校正
            if !self.isCalibrated {
                self.calibratedPitch /= 10.0
                self.calibratedRoll /= 10.0
                self.isCalibrated = true
            }
            
            let maxAngle: Double = 20
            let adjustedPitch = rawPitch - self.calibratedPitch
            let adjustedRoll = rawRoll - self.calibratedRoll
            
            self.pitch = max(-maxAngle, min(maxAngle, adjustedPitch * 0.8))
            self.roll = max(-maxAngle, min(maxAngle, adjustedRoll * 0.8))
        }
    }
    
    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
        isActive = false
        pitch = 0
        roll = 0
    }
    
    func recalibrate() {
        isCalibrated = false
    }
}

// MARK: - 閃卡效果類型
enum ShineEffectType: String, CaseIterable, Identifiable {
    case none = "無"
    case rainbow = "彩虹光"
    case holographic = "雷射標"
    case galaxy = "星空"
    case gold = "金箔"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .none: return "circle.slash"
        case .rainbow: return "rainbow"
        case .holographic: return "seal.fill"
        case .galaxy: return "sparkles"
        case .gold: return "star.fill"
        }
    }
}

struct ShineEffect: Identifiable, Equatable {
    var id: String { name }  // 用 name 作為 id
    let type: ShineEffectType
    let name: String
    let tier: TemplateTier
    
    // 所有閃卡效果（靜態列表）
    static let allEffects = [
        ShineEffect(type: .none, name: "無", tier: .free),
        ShineEffect(type: .rainbow, name: "彩虹光", tier: .free),
        ShineEffect(type: .holographic, name: "雷射標", tier: .paid),
        ShineEffect(type: .galaxy, name: "星空", tier: .free),
        ShineEffect(type: .gold, name: "金箔", tier: .paid),
    ]
    
    // 根據名稱查找效果
    static func find(byName name: String) -> ShineEffect? {
        return allEffects.first { $0.name == name }
    }
    
    static func == (lhs: ShineEffect, rhs: ShineEffect) -> Bool {
        lhs.name == rhs.name
    }
}

// 彈窗狀態
enum SheetPosition {
    case collapsed  // 收合
    case half       // 40% 高度
    case full       // 完全展開
}

struct EditorView: View {
    
    var onBack: () -> Void
    var existingDraft: CardDraft? = nil  // 如果是編輯現有草稿
    
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
    
    // 底部彈窗狀態
    @State private var sheetPosition: SheetPosition = .collapsed
    @State private var selectedTool: Int = 0
    @State private var sheetOffset: CGFloat = 0
    @State private var lastSheetOffset: CGFloat = 0
    
    // 選中的外框
    @State private var selectedFrame: FrameTemplate? = nil
    
    // 選中的閃卡效果
    @State private var selectedShineEffect: ShineEffect? = nil
    
    // 陀螺儀管理器
    @StateObject private var motionManager = MotionManager()
    
    // 儲存相關
    @State private var showSaveConfirmation = false
    @State private var showBackConfirmation = false
    @State private var isSaving = false
    @State private var currentDraftId: String?
    @State private var hasSaved = false  // 追蹤是否已儲存
    
    // 是否有未儲存的變更（必須有圖片才算）
    private var hasUnsavedChanges: Bool {
        // 如果已經儲存過，就沒有未儲存的變更
        if hasSaved { return false }
        // 必須有圖片才算有未儲存的變更
        return selectedImage != nil
    }
    
    // 是否可以儲存（必須有圖片）
    private var canSave: Bool {
        return selectedImage != nil && !isUploading
    }
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let toolbarHeight: CGFloat = 100
            let fullHeight = screenHeight - geometry.safeAreaInsets.top
            let halfHeight = screenHeight * 0.4
            
            ZStack {
                // 背景 - 淺灰色
                Color(hex: "F5F5F5").ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 頂部導航
                    EditorHeader(
                        onBack: {
                            if hasUnsavedChanges {
                                showBackConfirmation = true
                            } else {
                                onBack()
                            }
                        },
                        onSave: saveDraft,
                        canSave: canSave
                    )
                    
                    Spacer()
                    
                    // 預覽區域
                    EditorPreview(
                        selectedImage: selectedImage,
                        imageOffset: $imageOffset,
                        lastOffset: $lastOffset,
                        imageScale: $imageScale,
                        lastScale: $lastScale,
                        selectedFrame: selectedFrame,
                        selectedShineEffect: selectedShineEffect,
                        motionManager: motionManager
                    )
                    
                    Spacer()
                    
                    // 頁面縮略圖
                    EditorPageThumbnails(
                        currentPage: $currentPage,
                        selectedImage: selectedImage,
                        selectedItem: $selectedItem,
                        onImageSelected: loadImage
                    )
                    
                    // 底部工具欄佔位
                    Color.clear.frame(height: toolbarHeight)
                }
                
                // 可展開的底部彈窗
                ExpandableBottomSheet(
                    sheetPosition: $sheetPosition,
                    selectedTool: $selectedTool,
                    sheetOffset: $sheetOffset,
                    lastSheetOffset: $lastSheetOffset,
                    selectedItem: $selectedItem,
                    selectedFrame: $selectedFrame,
                    selectedShineEffect: $selectedShineEffect,
                    motionManager: motionManager,
                    onImageSelected: loadImage,
                    isUploading: isUploading,
                    screenHeight: screenHeight,
                    fullHeight: fullHeight,
                    halfHeight: halfHeight,
                    toolbarHeight: toolbarHeight,
                    safeAreaTop: geometry.safeAreaInsets.top
                )
                
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
                
                // 儲存成功提示
                if showSaveConfirmation {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "BFFF00"))
                        Text("已儲存草稿")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(16)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .alert("儲存草稿？", isPresented: $showBackConfirmation) {
            Button("不儲存", role: .destructive) {
                onBack()
            }
            Button("儲存並離開") {
                saveDraft()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onBack()
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("你有未儲存的變更，要在離開前儲存嗎？")
        }
        .onAppear {
            loadExistingDraft()
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
                        self.uploadImageToFirebase(image: image)
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
    
    // 儲存草稿
    private func saveDraft() {
        guard canSave else { return }
        
        isSaving = true
        
        // 先顯示確認彈窗
        showSaveConfirmation = true
        hasSaved = true
        
        // 在背景執行儲存
        DispatchQueue.global(qos: .userInitiated).async {
            var draft = CardDraft(
                id: self.currentDraftId ?? UUID().uuidString,
                createdAt: self.existingDraft?.createdAt ?? Date(),
                updatedAt: Date(),
                status: .saved
            )
            
            // 儲存圖片到檔案系統
            if let image = self.selectedImage {
                draft.saveImage(image)
            }
            
            DispatchQueue.main.async {
                draft.imageURL = self.uploadedImageURL
                draft.frameName = self.selectedFrame?.name
                draft.shineEffectName = self.selectedShineEffect?.name
                draft.imageOffsetX = self.imageOffset.width
                draft.imageOffsetY = self.imageOffset.height
                draft.imageScale = self.imageScale
                
                DraftManager.shared.saveDraft(draft)
                self.currentDraftId = draft.id
                self.isSaving = false
            }
        }
        
        // 2 秒後自動關閉確認提示
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showSaveConfirmation = false
        }
    }
    
    // 載入現有草稿
    private func loadExistingDraft() {
        guard let draft = existingDraft else { return }
        
        currentDraftId = draft.id
        uploadedImageURL = draft.imageURL
        
        // 載入圖片（從檔案系統）
        if let image = draft.localImage {
            selectedImage = image
        }
        
        // 載入圖片調整
        imageOffset = CGSize(width: draft.imageOffsetX, height: draft.imageOffsetY)
        lastOffset = imageOffset
        imageScale = draft.imageScale
        lastScale = imageScale
        
        // 載入外框
        if let frameName = draft.frameName {
            selectedFrame = FrameTemplate.find(byName: frameName)
        }
        
        // 載入閃卡效果
        if let shineEffectName = draft.shineEffectName {
            selectedShineEffect = ShineEffect.find(byName: shineEffectName)
        }
        
        // 已經是儲存過的草稿
        hasSaved = true
    }
}


// MARK: - 頂部導航
struct EditorHeader: View {
    var onBack: () -> Void
    var onSave: () -> Void
    var canSave: Bool = true
    
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
                Button(action: onSave) {
                    Image(systemName: "opticaldiscdrive.fill")
                        .font(.system(size: 16))
                        .foregroundColor(canSave ? .black : .gray.opacity(0.4))
                }
                .disabled(!canSave)
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
    var selectedFrame: FrameTemplate?
    var selectedShineEffect: ShineEffect?
    @ObservedObject var motionManager: MotionManager
    
    // 卡片尺寸常量
    private let cardWidth: CGFloat = 340
    private let cardHeight: CGFloat = 480
    
    // 是否啟用閃卡效果
    private var isShineEnabled: Bool {
        selectedShineEffect != nil && selectedShineEffect?.type != .none
    }
    
    var body: some View {
        // 卡片預覽
        ZStack {
            // 第一層：背景圖片或漸層
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
            
            // 第二層：外框圖層
            if let frame = selectedFrame {
                if let frameName = frame.frameImageName {
                    Image(frameName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: cardHeight)
                        .allowsHitTesting(false)
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: frame.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 12
                        )
                        .allowsHitTesting(false)
                }
            }
            
            // 第三層：閃卡效果（只有選擇後才顯示）
            if isShineEnabled, let effect = selectedShineEffect {
                ShineEffectView(
                    effectType: effect.type,
                    pitch: motionManager.pitch,
                    roll: motionManager.roll
                )
                .allowsHitTesting(false)
            }
            
            // 第四層：拖曳提示（有圖片時顯示）
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
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        // 3D 旋轉效果（只有啟用閃卡效果時）
        .rotation3DEffect(
            .degrees(isShineEnabled ? motionManager.roll : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .rotation3DEffect(
            .degrees(isShineEnabled ? -motionManager.pitch : 0),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.5
        )
        .shadow(
            color: Color.black.opacity(0.3),
            radius: 20,
            x: isShineEnabled ? CGFloat(motionManager.roll) * 0.5 : 0,
            y: isShineEnabled ? CGFloat(motionManager.pitch) * 0.5 + 10 : 10
        )
    }
}

// MARK: - 閃卡效果視圖（根據類型顯示不同效果）
struct ShineEffectView: View {
    let effectType: ShineEffectType
    let pitch: Double
    let roll: Double
    
    var body: some View {
        switch effectType {
        case .none:
            EmptyView()
        case .rainbow:
            RainbowShineEffect(pitch: pitch, roll: roll)
        case .holographic:
            HolographicWatermarkEffect(pitch: pitch, roll: roll)
        case .galaxy:
            GalaxyShineEffect(pitch: pitch, roll: roll)
        case .gold:
            GoldShineEffect(pitch: pitch, roll: roll)
        }
    }
}

// MARK: - 彩虹光效果
struct RainbowShineEffect: View {
    let pitch: Double
    let roll: Double
    
    var body: some View {
        GeometryReader { geometry in
            let offsetX = roll / 20.0
            let offsetY = pitch / 20.0
            
            ZStack {
                // 主要彩虹光帶
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.cyan.opacity(0.4),
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.4),
                        Color.pink.opacity(0.3),
                        Color.orange.opacity(0.3),
                        Color.yellow.opacity(0.3),
                        Color.white.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: UnitPoint(x: 0.0 + offsetX, y: 0.0 + offsetY),
                    endPoint: UnitPoint(x: 1.0 + offsetX, y: 1.0 + offsetY)
                )
                .blendMode(.plusLighter)
                
                // 高光點
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.6),
                        Color.white.opacity(0.2),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.3 + offsetX * 2, y: 0.2 + offsetY * 2),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.5
                )
                .blendMode(.plusLighter)
            }
        }
    }
}

// MARK: - 雷射標/浮水印效果
struct HolographicWatermarkEffect: View {
    let pitch: Double
    let roll: Double
    
    var body: some View {
        GeometryReader { geometry in
            let offsetX = roll / 15.0
            let offsetY = pitch / 15.0
            
            ZStack {
                // 重複的浮水印圖案
                Canvas { context, size in
                    let patternSize: CGFloat = 60
                    let rows = Int(size.height / patternSize) + 2
                    let cols = Int(size.width / patternSize) + 2
                    
                    for row in 0..<rows {
                        for col in 0..<cols {
                            let x = CGFloat(col) * patternSize + CGFloat(offsetX * 10)
                            let y = CGFloat(row) * patternSize + CGFloat(offsetY * 10)
                            
                            // 交錯排列
                            let offsetRow = row % 2 == 0 ? 0 : patternSize / 2
                            
                            let rect = CGRect(
                                x: x + offsetRow,
                                y: y,
                                width: patternSize * 0.6,
                                height: patternSize * 0.6
                            )
                            
                            // 繪製菱形
                            var path = Path()
                            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
                            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
                            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
                            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
                            path.closeSubpath()
                            
                            context.stroke(path, with: .color(.white.opacity(0.15)), lineWidth: 1)
                        }
                    }
                }
                
                // 彩虹漸層覆蓋
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.cyan.opacity(0.2),
                        Color.purple.opacity(0.25),
                        Color.pink.opacity(0.2),
                        Color.yellow.opacity(0.15),
                        Color.green.opacity(0.2),
                        Color.blue.opacity(0.25),
                        Color.clear
                    ],
                    startPoint: UnitPoint(x: -0.5 + offsetX, y: -0.5 + offsetY),
                    endPoint: UnitPoint(x: 1.5 + offsetX, y: 1.5 + offsetY)
                )
                .blendMode(.plusLighter)
                
                // 光澤條紋
                ForEach(0..<3, id: \.self) { i in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.4),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.15, height: geometry.size.height * 2)
                        .rotationEffect(.degrees(35))
                        .offset(
                            x: CGFloat(-100 + i * 150) + CGFloat(offsetX * 50),
                            y: CGFloat(offsetY * 30)
                        )
                        .blendMode(.plusLighter)
                }
            }
        }
    }
}

// MARK: - 星空效果
struct GalaxyShineEffect: View {
    let pitch: Double
    let roll: Double
    
    var body: some View {
        GeometryReader { geometry in
            let offsetX = roll / 20.0
            let offsetY = pitch / 20.0
            
            ZStack {
                // 星點
                Canvas { context, size in
                    let starCount = 50
                    for i in 0..<starCount {
                        let seed = Double(i * 12345)
                        let x = (sin(seed) * 0.5 + 0.5) * size.width + CGFloat(offsetX * 5)
                        let y = (cos(seed * 1.5) * 0.5 + 0.5) * size.height + CGFloat(offsetY * 5)
                        let starSize = (sin(seed * 2) * 0.5 + 0.5) * 3 + 1
                        
                        let rect = CGRect(x: x, y: y, width: starSize, height: starSize)
                        context.fill(Circle().path(in: rect), with: .color(.white.opacity(0.6)))
                    }
                }
                
                // 銀河漸層
                RadialGradient(
                    colors: [
                        Color.purple.opacity(0.3),
                        Color.blue.opacity(0.2),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5 + offsetX, y: 0.5 + offsetY),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.8
                )
                .blendMode(.plusLighter)
            }
        }
    }
}

// MARK: - 金箔效果
struct GoldShineEffect: View {
    let pitch: Double
    let roll: Double
    
    var body: some View {
        GeometryReader { geometry in
            let offsetX = roll / 20.0
            let offsetY = pitch / 20.0
            
            ZStack {
                // 金色光澤
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.yellow.opacity(0.3),
                        Color.orange.opacity(0.4),
                        Color.yellow.opacity(0.5),
                        Color.white.opacity(0.3),
                        Color.yellow.opacity(0.4),
                        Color.orange.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: UnitPoint(x: 0.0 + offsetX, y: 0.0 + offsetY),
                    endPoint: UnitPoint(x: 1.0 + offsetX, y: 1.0 + offsetY)
                )
                .blendMode(.plusLighter)
                
                // 高光
                RadialGradient(
                    colors: [
                        Color.white.opacity(0.5),
                        Color.yellow.opacity(0.3),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.3 + offsetX * 2, y: 0.2 + offsetY * 2),
                    startRadius: 0,
                    endRadius: geometry.size.width * 0.4
                )
                .blendMode(.plusLighter)
            }
        }
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
        ("rectangle.inset.filled", "外框"),
        ("doc.text.fill", "卡片內容"),
        ("sparkles", "閃卡效果"),
        ("rectangle.split.2x1.fill", "分割"),
        ("square.and.arrow.up", "分享"),
        ("diamond.fill", "GEM")
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

// MARK: - 可展開的底部彈窗
struct ExpandableBottomSheet: View {
    @Binding var sheetPosition: SheetPosition
    @Binding var selectedTool: Int
    @Binding var sheetOffset: CGFloat
    @Binding var lastSheetOffset: CGFloat
    @Binding var selectedItem: PhotosPickerItem?
    @Binding var selectedFrame: FrameTemplate?
    @Binding var selectedShineEffect: ShineEffect?
    @ObservedObject var motionManager: MotionManager
    var onImageSelected: (PhotosPickerItem?) -> Void
    var isUploading: Bool
    
    let screenHeight: CGFloat
    let fullHeight: CGFloat
    let halfHeight: CGFloat
    let toolbarHeight: CGFloat
    let safeAreaTop: CGFloat
    
    let tools = [
        ("square.grid.2x2", "設計"),
        ("rectangle.inset.filled", "外框"),
        ("doc.text.fill", "卡片內容"),
        ("sparkles", "閃卡效果"),
        ("rectangle.split.2x1.fill", "分割"),
        ("square.and.arrow.up", "分享"),
        ("diamond.fill", "GEM")
    ]
    
    // 計算當前應該的高度
    var currentHeight: CGFloat {
        switch sheetPosition {
        case .collapsed:
            return toolbarHeight
        case .half:
            return halfHeight
        case .full:
            return fullHeight
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // 拖曳指示器
                if sheetPosition != .collapsed {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.gray.opacity(0.4))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                }
                
                // 展開後的內容區域
                if sheetPosition != .collapsed {
                    VStack(spacing: 0) {
                        // 頂部標題
                        HStack {
                            Text(tools[selectedTool].1)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    sheetPosition = .collapsed
                                }
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        
                        // 內容區域 - 根據選擇的工具顯示不同內容
                        ScrollView {
                            if selectedTool == 1 {
                                // 外框內容
                                ElementsContentView(selectedFrame: $selectedFrame)
                            } else if selectedTool == 3 {
                                // 閃卡效果內容
                                ShineEffectsContentView(
                                    selectedShineEffect: $selectedShineEffect,
                                    motionManager: motionManager
                                )
                            } else {
                                VStack {
                                    Text("這裡是 \(tools[selectedTool].1) 的內容")
                                        .foregroundColor(.gray)
                                        .padding(.top, 40)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                
                // 底部工具欄
                HStack(spacing: 0) {
                    ForEach(0..<tools.count, id: \.self) { index in
                        Button(action: {
                            selectedTool = index
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if sheetPosition == .collapsed {
                                    sheetPosition = .full
                                }
                            }
                        }) {
                            VStack(spacing: 6) {
                                Image(systemName: tools[index].0)
                                    .font(.system(size: 20))
                                    .frame(height: 24)
                                    .foregroundColor(selectedTool == index ? Color(hex: "7CB342") : .gray)
                                
                                Text(tools[index].1)
                                    .font(.system(size: 10))
                                    .frame(height: 14)
                                    .foregroundColor(selectedTool == index ? Color(hex: "7CB342") : .gray)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                        }
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 28)
                .background(Color.white)
            }
            .frame(height: currentHeight + sheetOffset)
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .clipShape(
                RoundedCorner(radius: sheetPosition == .collapsed ? 0 : 20, corners: [.topLeft, .topRight])
            )
            .shadow(color: Color.black.opacity(sheetPosition == .collapsed ? 0 : 0.1), radius: 10, x: 0, y: -5)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // 只在展開狀態下可拖曳
                        if sheetPosition != .collapsed {
                            let dragAmount = value.translation.height
                            sheetOffset = -dragAmount
                        }
                    }
                    .onEnded { value in
                        let dragAmount = value.translation.height
                        let velocity = value.predictedEndTranslation.height - value.translation.height
                        
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            sheetOffset = 0
                            
                            if sheetPosition == .full {
                                // 從完全展開狀態
                                if dragAmount > 100 || velocity > 500 {
                                    // 下拉超過閾值，切換到半高
                                    sheetPosition = .half
                                }
                            } else if sheetPosition == .half {
                                // 從半高狀態
                                if dragAmount > 80 || velocity > 400 {
                                    // 下拉，收合
                                    sheetPosition = .collapsed
                                } else if dragAmount < -80 || velocity < -400 {
                                    // 上拉，完全展開
                                    sheetPosition = .full
                                }
                            }
                        }
                    }
            )
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

// MARK: - 元素內容視圖
struct ElementsContentView: View {
    @Binding var selectedFrame: FrameTemplate?
    
    // 範本資料
    // frameImageName: 放入 Assets 的圖片名稱（1020x1440 PNG，中間透明）
    let templates = FrameTemplate.allTemplates
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("外框範本")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(templates) { template in
                    FrameTemplateCard(
                        template: template,
                        isSelected: selectedFrame?.id == template.id,
                        onSelect: {
                            if selectedFrame?.id == template.id {
                                selectedFrame = nil
                            } else {
                                selectedFrame = template
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

// MARK: - 閃卡效果內容視圖
struct ShineEffectsContentView: View {
    @Binding var selectedShineEffect: ShineEffect?
    @ObservedObject var motionManager: MotionManager
    
    // 閃卡效果資料
    let effects = ShineEffect.allEffects
    
    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("閃卡效果")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            Text("選擇效果後，傾斜手機可看到閃光")
                .font(.system(size: 12))
                .foregroundColor(.gray.opacity(0.7))
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(effects) { effect in
                    ShineEffectCard(
                        effect: effect,
                        isSelected: selectedShineEffect?.id == effect.id,
                        onSelect: {
                            if selectedShineEffect?.id == effect.id {
                                selectedShineEffect = nil
                                motionManager.stopMotionUpdates()
                            } else {
                                selectedShineEffect = effect
                                if effect.type != .none {
                                    motionManager.startMotionUpdates()
                                } else {
                                    motionManager.stopMotionUpdates()
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
}

// MARK: - 閃卡效果卡片
struct ShineEffectCard: View {
    let effect: ShineEffect
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // 效果預覽
                ZStack(alignment: .topLeading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.5),
                                    Color.blue.opacity(0.4),
                                    Color.pink.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(340/480, contentMode: .fit)
                    
                    // 效果圖示
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: effect.type.iconName)
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        Spacer()
                    }
                    
                    // 選中指示器（左上角）
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "BFFF00"))
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .padding(8)
                    }
                }
                // 選中邊框
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(hex: "BFFF00") : Color.clear, lineWidth: 4)
                )
                // 選中時加陰影
                .shadow(color: isSelected ? Color(hex: "BFFF00").opacity(0.5) : Color.clear, radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                // 效果名稱
                Text(effect.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                
                // Tier 標籤
                Text(effect.tier == .free ? "Free" : "Paid")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        effect.tier == .free
                            ? Color.gray.opacity(0.2)
                            : Color(hex: "BFFF00")
                    )
                    .cornerRadius(8)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 範本資料模型
struct FrameTemplate: Identifiable, Equatable {
    var id: String { name }  // 用 name 作為 id
    let name: String
    let tier: TemplateTier
    let matchRate: Int
    let frameImageName: String? // 外框圖片名稱（放在 Assets 裡）
    
    // 所有外框模板（靜態列表）
    static let allTemplates = [
        FrameTemplate(name: "經典邊框", tier: .free, matchRate: 94, frameImageName: nil),
        FrameTemplate(name: "霓虹光暈", tier: .paid, matchRate: 97, frameImageName: nil),
        FrameTemplate(name: "極簡白框", tier: .free, matchRate: 89, frameImageName: nil),
        FrameTemplate(name: "金屬質感", tier: .free, matchRate: 91, frameImageName: nil),
        FrameTemplate(name: "漸層波浪", tier: .paid, matchRate: 96, frameImageName: nil),
        FrameTemplate(name: "復古相框", tier: .free, matchRate: 85, frameImageName: nil),
    ]
    
    // 根據名稱查找模板
    static func find(byName name: String) -> FrameTemplate? {
        return allTemplates.first { $0.name == name }
    }
    
    // 隨機漸層顏色（暫時用於示意）
    var gradientColors: [Color] {
        let colorSets: [[Color]] = [
            [.purple.opacity(0.7), .blue.opacity(0.5), .pink.opacity(0.6)],
            [.orange.opacity(0.7), .red.opacity(0.5), .yellow.opacity(0.6)],
            [.green.opacity(0.7), .teal.opacity(0.5), .blue.opacity(0.6)],
            [.indigo.opacity(0.7), .purple.opacity(0.5), .pink.opacity(0.6)],
            [.cyan.opacity(0.7), .blue.opacity(0.5), .indigo.opacity(0.6)],
            [.pink.opacity(0.7), .red.opacity(0.5), .orange.opacity(0.6)],
        ]
        return colorSets[abs(name.hashValue) % colorSets.count]
    }
    
    static func == (lhs: FrameTemplate, rhs: FrameTemplate) -> Bool {
        lhs.name == rhs.name
    }
}

enum TemplateTier {
    case free
    case paid
}

// MARK: - 範本卡片
struct FrameTemplateCard: View {
    let template: FrameTemplate
    let isSelected: Bool
    let onSelect: () -> Void
    
    // 卡片比例 340:480
    private let cardRatio: CGFloat = 340 / 480
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // 卡片預覽
                ZStack(alignment: .topLeading) {
                    // 漸層背景（之後會替換成真實外框圖片）
                    if let imageName = template.frameImageName {
                        // 使用自訂圖片
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(cardRatio, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        // 暫時用漸層示意
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: template.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .aspectRatio(cardRatio, contentMode: .fit)
                            .overlay(
                                // 示意外框邊框
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [.white.opacity(0.8), .white.opacity(0.3)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 4
                                    )
                            )
                    }
                    
                    // 推薦程度標籤（右下角）
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                Text("\(template.matchRate)%")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(hex: "BFFF00"))
                            .cornerRadius(12)
                            .padding(8)
                        }
                    }
                    
                    // 選中指示器（左上角）
                    if isSelected {
                        ZStack {
                            Circle()
                                .fill(Color(hex: "BFFF00"))
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        .padding(8)
                    }
                }
                // 選中邊框
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(hex: "BFFF00") : Color.clear, lineWidth: 4)
                )
                // 選中時加陰影
                .shadow(color: isSelected ? Color(hex: "BFFF00").opacity(0.5) : Color.clear, radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                // 範本名稱
                Text(template.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.black)
                
                // Tier 標籤
                Text(template.tier == .free ? "Free" : "Paid")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        template.tier == .free
                            ? Color.gray.opacity(0.2)
                            : Color(hex: "BFFF00")
                    )
                    .cornerRadius(8)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 圓角輔助
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    EditorView(onBack: {})
}
