//
//  DraftsView.swift
//  holocard
//

import SwiftUI

struct DraftsView: View {
    @State private var searchText = ""
    @State private var selectedCategory: DraftStatus = .saved
    @State private var drafts: [CardDraft] = []
    
    var onSelectDraft: ((CardDraft) -> Void)? = nil
    var onTabChange: ((Int) -> Void)? = nil
    
    // 篩選後的草稿
    var filteredDrafts: [CardDraft] {
        let categoryFiltered = drafts.filter { $0.status == selectedCategory }
        if searchText.isEmpty {
            return categoryFiltered
        }
        return categoryFiltered.filter { draft in
            (draft.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (draft.frameName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        ZStack {
            // 背景
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 頂部區域（綠色背景）
                VStack(spacing: 16) {
                    // 標題
                    HStack {
                        Text("My Drafts")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    
                    // 搜尋欄
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        
                        TextField("搜尋草稿...", text: $searchText)
                            .font(.system(size: 16))
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 20)
                .background(Color(hex: "BFFF00"))
                
                // 主內容
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Category 標題
                        Text("Category")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        
                        // Tags
                        HStack(spacing: 12) {
                            ForEach(DraftStatus.allCases, id: \.self) { status in
                                Button(action: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        selectedCategory = status
                                    }
                                }) {
                                    Text(status.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(selectedCategory == status ? .black : .gray)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(
                                            selectedCategory == status
                                                ? Color(hex: "BFFF00").opacity(0.4)
                                                : Color.clear
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(selectedCategory == status ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                        .cornerRadius(20)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        // 卡片顯示
                        if filteredDrafts.isEmpty {
                            // 空狀態
                            VStack(spacing: 16) {
                                Image(systemName: "tray")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.5))
                                
                                Text(selectedCategory == .saved ? "沒有已儲存的草稿" : "沒有已發布的卡片")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                Text("開始製作你的第一張 HoloCard！")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                        } else {
                            // 卡片堆疊（可左右滑動）
                            CardStackView(
                                drafts: filteredDrafts,
                                onSelectDraft: { draft in
                                    onSelectDraft?(draft)
                                },
                                onDeleteDraft: { draft in
                                    // 執行刪除
                                    DraftManager.shared.deleteDraft(draft)
                                    drafts = DraftManager.shared.drafts
                                }
                            )
                            .padding(.top, 10)
                        }
                    }
                    .padding(.bottom, 120)
                }
                
                Spacer(minLength: 0)
            }
            
            // 底部導航（固定在底部）
            VStack {
                Spacer()
                BottomTabBar(selectedTab: 1, onTabChange: { tab in
                    onTabChange?(tab)
                })
            }
        }
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            drafts = DraftManager.shared.drafts
        }
    }
}

// MARK: - 卡片堆疊視圖（照參考圖樣式）
struct CardStackView: View {
    let drafts: [CardDraft]
    let onSelectDraft: (CardDraft) -> Void
    let onDeleteDraft: (CardDraft) -> Void
    
    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var draftToDelete: CardDraft? = nil
    
    // 卡片尺寸（與 EditorView 一致 340:480 比例）
    private let cardWidth: CGFloat = UIScreen.main.bounds.width * 0.7
    private var cardHeight: CGFloat { cardWidth * (480.0 / 340.0) }  // 340:480 比例
    
    var body: some View {
        VStack(spacing: 20) {
            // 卡片區域
            ZStack {
                ForEach(0..<drafts.count, id: \.self) { index in
                    let offset = index - currentIndex
                    
                    // 只顯示當前、前一張、後兩張
                    if offset >= -1 && offset <= 2 {
                        StackedCard(draft: drafts[index])
                            .frame(width: cardWidth, height: cardHeight)
                            .scaleEffect(scaleFor(offset: offset))
                            .offset(x: xOffsetFor(offset: offset), y: yOffsetFor(offset: offset))
                            .rotationEffect(.degrees(rotationFor(offset: offset, index: index)))
                            .opacity(opacityFor(offset: offset))
                            .zIndex(zIndexFor(offset: offset))
                            .onTapGesture {
                                if !isDragging && offset == 0 {
                                    onSelectDraft(drafts[index])
                                }
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    draftToDelete = drafts[index]
                                    showDeleteAlert = true
                                } label: {
                                    Label("刪除", systemImage: "trash")
                                }
                            }
                    }
                }
            }
            .frame(width: UIScreen.main.bounds.width, height: cardHeight + 40)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 60
                        
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if value.translation.width < -threshold && currentIndex < drafts.count - 1 {
                                currentIndex += 1
                            } else if value.translation.width > threshold && currentIndex > 0 {
                                currentIndex -= 1
                            }
                            dragOffset = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            isDragging = false
                        }
                    }
            )
            
            // 頁面指示器
            if drafts.count > 1 {
                HStack(spacing: 8) {
                    ForEach(0..<drafts.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color(hex: "BFFF00") : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            
            // 頁碼
            Text("\(currentIndex + 1) / \(drafts.count)")
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .alert("刪除草稿", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) { }
            Button("刪除", role: .destructive) {
                if let draft = draftToDelete {
                    onDeleteDraft(draft)
                    // 調整 currentIndex 避免越界
                    if currentIndex >= drafts.count - 1 && currentIndex > 0 {
                        currentIndex -= 1
                    }
                }
            }
        } message: {
            Text("確定要刪除這個草稿嗎？此操作無法復原。")
        }
    }
    
    // 縮放
    private func scaleFor(offset: Int) -> CGFloat {
        switch offset {
        case -1: return 0.85  // 左邊（前一張）
        case 0: return 1.0    // 當前
        case 1: return 0.9    // 右邊第一張
        case 2: return 0.8    // 右邊第二張
        default: return 0.75
        }
    }
    
    // X 偏移
    private func xOffsetFor(offset: Int) -> CGFloat {
        let baseOffset: CGFloat
        switch offset {
        case -1: baseOffset = -cardWidth * 0.75  // 左邊露出一部分
        case 0: baseOffset = 0
        case 1: baseOffset = cardWidth * 0.15 + 20  // 右邊第一張
        case 2: baseOffset = cardWidth * 0.25 + 35  // 右邊第二張
        default: baseOffset = 0
        }
        
        // 拖曳時跟隨
        if offset == 0 {
            return baseOffset + dragOffset
        } else if offset == -1 {
            return baseOffset + dragOffset * 0.5
        } else {
            return baseOffset + dragOffset * 0.3
        }
    }
    
    // Y 偏移
    private func yOffsetFor(offset: Int) -> CGFloat {
        switch offset {
        case -1: return 0
        case 0: return 0
        case 1: return 15
        case 2: return 25
        default: return 0
        }
    }
    
    // 旋轉角度（後面的卡片微微傾斜）
    private func rotationFor(offset: Int, index: Int) -> Double {
        switch offset {
        case -1: return -3
        case 0: return 0
        case 1: return 2 + Double(index % 2) * 2
        case 2: return 4 + Double(index % 3)
        default: return 0
        }
    }
    
    // 透明度 - 全部不透明
    private func opacityFor(offset: Int) -> Double {
        return 1.0  // 全部都是完全不透明
    }
    
    // Z 軸順序
    private func zIndexFor(offset: Int) -> Double {
        switch offset {
        case -1: return 1
        case 0: return 10
        case 1: return 5
        case 2: return 3
        default: return 0
        }
    }
}

// MARK: - 單張卡片（固定 340:480 比例，含外框）
struct StackedCard: View {
    let draft: CardDraft
    
    // 獲取外框模板
    private var frameTemplate: FrameTemplate? {
        guard let name = draft.frameName else { return nil }
        return FrameTemplate.find(byName: name)
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // 外框背景
                if let template = frameTemplate {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: template.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    // 沒有外框時的白色背景
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                }
                
                // 圖片（從檔案系統讀取，內縮顯示外框）
                if let uiImage = draft.localImage {
                    let frameWidth: CGFloat = frameTemplate != nil ? 12 : 0
                    
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geo.size.width - frameWidth * 2,
                            height: geo.size.height - frameWidth * 2
                        )
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: frameTemplate != nil ? 12 : 20))
                        .padding(frameWidth)
                } else {
                    // 預設漸層（不透明）
                    LinearGradient(
                        colors: [Color.purple, Color.blue, Color.pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                
                // 底部資訊
                VStack(alignment: .leading, spacing: 6) {
                    Text(draft.title ?? "未命名卡片")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                        Text(draft.status.displayName)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        }
    }
}

#Preview {
    DraftsView()
}
