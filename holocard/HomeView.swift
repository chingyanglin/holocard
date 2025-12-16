//
//  HomeView.swift
//  holocard
//

import SwiftUI
import FirebaseAuth

struct HomeView: View {
    
    @ObservedObject var authVM: AuthViewModel
    @StateObject private var userService = UserService.shared
    @State private var selectedCategory = "Silver"
    @State private var searchText = ""
    @State private var isReady = false  // 延遲載入控制
    var onNavigateToEditor: (() -> Void)? = nil
    var onNavigateToProfile: (() -> Void)? = nil
    var onNavigateToDrafts: (() -> Void)? = nil  // 新增
    
    let categories = ["Silver", "Gold", "Flash", "Ruby", "Platinum", "Diamond"]
    
    var body: some View {
        ZStack {
            // 背景
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 頂部區域
                HeaderSection(
                    userName: displayName,
                    photoURL: userService.userProfile?.photoURL ?? "",
                    onProfileTap: { onNavigateToProfile?() }
                )
                
                // 搜尋框
                // 建立按鈕
                Button(action: {
                    onNavigateToEditor?()
                }) {
                    Text("Create your holocard")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            ZStack {
                                // 底層漸層
                                LinearGradient(
                                    colors: [Color(hex: "BFFF00"), Color(hex: "00FF88")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                
                                // 頂部光澤
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.white.opacity(0)],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            }
                        )
                        .cornerRadius(26)
                        .shadow(color: Color(hex: "BFFF00").opacity(0.5), radius: 10, x: 0, y: 5)
                        .shadow(color: Color(hex: "00FF88").opacity(0.3), radius: 15, x: 0, y: 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 標題
                Text("Design your first card")
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .tracking(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                
                // 分類標籤
                CategoryTabs(categories: categories, selected: $selectedCategory)
                    .padding(.top, 16)
                
                // 卡片輪播 - 延遲載入
                if isReady {
                    CardCarousel(selectedCategory: selectedCategory)
                        .padding(.top, 16)
                } else {
                    // 骨架屏
                    CardSkeletonView()
                        .padding(.top, 16)
                }
                
                Spacer(minLength: 0)
                
                // 底部導航
                BottomTabBar(selectedTab: 0, onTabChange: { tab in
                    if tab == 1 {
                        onNavigateToDrafts?()  // 愛心 = 草稿頁
                    } else if tab == 3 {
                        onNavigateToProfile?()
                    }
                })
            }
        }
        .onAppear {
            loadUserProfile()
            // 延遲載入卡片，讓 UI 先渲染
            if !isReady {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isReady = true
                    }
                }
            }
        }
    }
    
    // 顯示名稱邏輯
    private var displayName: String {
        if let profile = userService.userProfile, !profile.displayName.isEmpty {
            return profile.displayName
        }
        return authVM.user?.email ?? "User"
    }
    
    // 載入用戶資料（只在需要時載入）
    private func loadUserProfile() {
        guard let userId = authVM.user?.uid else { return }
        // 如果已經有資料，不重複載入
        if userService.userProfile != nil { return }
        userService.fetchUserProfile(userId: userId)
    }
}

// MARK: - 頂部區域
struct HeaderSection: View {
    let userName: String
    let photoURL: String
    var onProfileTap: () -> Void
    
    @State private var isSpinning = false
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 12) {
                // 會員等級
                HStack(spacing: 6) {
                    Text("會員等級")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                    
                    Text("Noobie")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(8)
                }
                
                // 用戶名稱
                Text(userName)
                    .font(.system(size: 24, weight: .semibold, design: .default))
                    .tracking(0.3)
            }
            
            Spacer()
            
            // 用戶頭像按鈕
            Button(action: onProfileTap) {
                ProfileImageView(photoURL: photoURL, isSpinning: isSpinning)
            }
            .onLongPressGesture(minimumDuration: 0.1) {
                isSpinning = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isSpinning = false
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - 頭像圖片（獨立組件避免重繪）
struct ProfileImageView: View {
    let photoURL: String
    let isSpinning: Bool
    
    var body: some View {
        Group {
            if !photoURL.isEmpty, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure(_):
                        placeholderImage
                    case .empty:
                        ProgressView()
                            .frame(width: 44, height: 44)
                    @unknown default:
                        placeholderImage
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                )
            } else {
                Image(systemName: "sparkle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.clear)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                    )
            }
        }
        .rotationEffect(.degrees(isSpinning ? 720 : 0))
        .animation(.easeInOut(duration: 0.8), value: isSpinning)
    }
    
    private var placeholderImage: some View {
        Circle()
            .fill(Color.gray.opacity(0.2))
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - 搜尋框
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 16))
            
            TextField("Search templates...", text: $text)
                .font(.system(size: 15))
            
            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
            }
        }
        .padding(14)
        .background(Color.gray.opacity(0.08))
        .cornerRadius(14)
    }
}

// MARK: - 分類標籤
struct CategoryTabs: View {
    let categories: [String]
    @Binding var selected: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(categories, id: \.self) { category in
                    CategoryTab(
                        title: category,
                        isSelected: selected == category
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selected = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct CategoryTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(colorForCategory(title))
                    .frame(width: 20, height: 20)
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .tracking(0.3)
            }
            .foregroundColor(isSelected ? .black : .gray)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                isSelected ? Color(hex: "BFFF00").opacity(0.4) : Color.clear
            )
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(isSelected ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    func colorForCategory(_ name: String) -> Color {
        switch name {
        case "Silver": return .gray
        case "Gold": return .yellow
        case "Flash": return .blue
        case "Ruby": return .red
        case "Platinum": return .purple
        case "Diamond": return .cyan
        default: return .gray
        }
    }
}

// MARK: - 卡片骨架屏（載入中）
struct CardSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.75
            let cardHeight = geometry.size.height - 20
            
            HStack(spacing: 12) {
                // 左側卡片（模糊）
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(0.9)
                    .opacity(0.6)
                
                // 中間卡片（主要）
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                            startPoint: isAnimating ? .leading : .trailing,
                            endPoint: isAnimating ? .trailing : .leading
                        )
                    )
                    .frame(width: cardWidth, height: cardHeight)
                
                // 右側卡片（模糊）
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: cardWidth, height: cardHeight)
                    .scaleEffect(0.9)
                    .opacity(0.6)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .padding(.bottom, 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - 卡片輪播
struct CardCarousel: View {
    let selectedCategory: String
    @State private var currentIndex = 1
    @GestureState private var dragOffset: CGFloat = 0
    
    // 根據分類返回不同的卡片
    var cards: [CardData] {
        switch selectedCategory {
        case "Silver":
            return [
                CardData(title: "Midnight Glow", subtitle: "Holographic effects with deep blue shimmer", rating: 5.0, colors: [.purple.opacity(0.7), .blue.opacity(0.5), .pink.opacity(0.6)]),
                CardData(title: "Aurora Flash", subtitle: "Rainbow spectrum with dynamic lighting", rating: 4.8, colors: [.blue.opacity(0.6), .purple.opacity(0.5), .cyan.opacity(0.6)]),
                CardData(title: "Silver Mist", subtitle: "Elegant silver finish with soft gradients", rating: 4.9, colors: [.gray.opacity(0.6), .white.opacity(0.5), .gray.opacity(0.7)])
            ]
        case "Gold":
            return [
                CardData(title: "Golden Hour", subtitle: "Warm tones with metallic finish", rating: 4.9, colors: [.yellow.opacity(0.7), .orange.opacity(0.6), .yellow.opacity(0.5)]),
                CardData(title: "Sunset Blaze", subtitle: "Rich golden gradients with warm highlights", rating: 4.7, colors: [.orange.opacity(0.7), .yellow.opacity(0.5), .red.opacity(0.4)]),
                CardData(title: "Royal Gold", subtitle: "Premium gold texture with luxury feel", rating: 5.0, colors: [.yellow.opacity(0.8), .brown.opacity(0.4), .orange.opacity(0.6)])
            ]
        case "Flash":
            return [
                CardData(title: "Electric Blue", subtitle: "Vibrant electric effects with neon glow", rating: 4.8, colors: [.blue.opacity(0.8), .cyan.opacity(0.7), .blue.opacity(0.5)]),
                CardData(title: "Lightning Strike", subtitle: "Dynamic flash patterns with energy bursts", rating: 4.6, colors: [.cyan.opacity(0.7), .white.opacity(0.5), .blue.opacity(0.6)]),
                CardData(title: "Neon Pulse", subtitle: "Pulsating neon lights with cyber aesthetic", rating: 4.9, colors: [.blue.opacity(0.6), .purple.opacity(0.5), .cyan.opacity(0.7)])
            ]
        case "Ruby":
            return [
                CardData(title: "Ruby Fire", subtitle: "Deep red tones with fiery gradients", rating: 5.0, colors: [.red.opacity(0.8), .pink.opacity(0.5), .red.opacity(0.6)]),
                CardData(title: "Crimson Wave", subtitle: "Elegant crimson with flowing patterns", rating: 4.7, colors: [.red.opacity(0.7), .orange.opacity(0.4), .pink.opacity(0.5)]),
                CardData(title: "Blood Moon", subtitle: "Mysterious dark red with lunar vibes", rating: 4.8, colors: [.red.opacity(0.9), .black.opacity(0.3), .red.opacity(0.5)])
            ]
        case "Platinum":
            return [
                CardData(title: "Platinum Edge", subtitle: "Sleek platinum with sharp contrasts", rating: 4.9, colors: [.gray.opacity(0.5), .purple.opacity(0.4), .gray.opacity(0.6)]),
                CardData(title: "Crystal Clear", subtitle: "Transparent platinum with crystal effects", rating: 4.8, colors: [.purple.opacity(0.5), .gray.opacity(0.4), .white.opacity(0.5)]),
                CardData(title: "Platinum Dreams", subtitle: "Dreamy platinum gradients with soft glow", rating: 5.0, colors: [.gray.opacity(0.6), .purple.opacity(0.5), .pink.opacity(0.4)])
            ]
        case "Diamond":
            return [
                CardData(title: "Diamond Shine", subtitle: "Brilliant diamond sparkle with clarity", rating: 5.0, colors: [.cyan.opacity(0.6), .white.opacity(0.5), .blue.opacity(0.4)]),
                CardData(title: "Ice Crystal", subtitle: "Frozen diamond texture with icy tones", rating: 4.9, colors: [.white.opacity(0.6), .cyan.opacity(0.5), .blue.opacity(0.4)]),
                CardData(title: "Prism Light", subtitle: "Rainbow refractions through diamond facets", rating: 4.8, colors: [.cyan.opacity(0.5), .pink.opacity(0.4), .yellow.opacity(0.3)])
            ]
        default:
            return []
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * 0.75
            let cardHeight = geometry.size.height - 20
            let spacing: CGFloat = 12
            
            HStack(spacing: spacing) {
                ForEach(0..<cards.count, id: \.self) { index in
                    // 只渲染可見的卡片（當前 ±1）
                    if abs(index - currentIndex) <= 1 {
                        CardView(card: cards[index])
                            .frame(width: cardWidth, height: cardHeight)
                            .scaleEffect(currentIndex == index ? 1.0 : 0.9)
                            .opacity(currentIndex == index ? 1.0 : 0.6)
                    } else {
                        // 佔位符（不渲染內容）
                        Color.clear
                            .frame(width: cardWidth, height: cardHeight)
                    }
                }
            }
            .offset(x: -CGFloat(currentIndex) * (cardWidth + spacing) + (geometry.size.width - cardWidth) / 2 + dragOffset)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentIndex)
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        let threshold = cardWidth / 3
                        var newIndex = currentIndex
                        
                        if value.translation.width < -threshold {
                            newIndex = min(currentIndex + 1, cards.count - 1)
                        } else if value.translation.width > threshold {
                            newIndex = max(currentIndex - 1, 0)
                        }
                        
                        currentIndex = newIndex
                    }
            )
        }
        .padding(.bottom, 10)
        .onChange(of: selectedCategory) { _ in
            currentIndex = 1
        }
    }
}

struct CardData {
    let title: String
    let subtitle: String
    let rating: Double
    let colors: [Color]
}

struct CardView: View {
    let card: CardData
    @State private var isLiked = false
    
    var body: some View {
        ZStack {
            // 背景漸層 - 使用卡片自己的顏色
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: card.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 內容
            VStack {
                // 頂部：評分 & 愛心
                HStack {
                    // 評分
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 12))
                        Text(String(format: "%.1f", card.rating))
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))
                    .cornerRadius(14)
                    
                    Spacer()
                    
                    // 愛心
                    Button(action: { isLiked.toggle() }) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16))
                            .foregroundColor(isLiked ? .red : .white)
                            .padding(12)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(14)
                    }
                }
                .padding(20)
                
                Spacer()
                
                // 底部：標題 & 箭頭
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(card.title)
                            .font(.system(size: 26, weight: .semibold, design: .default))
                            .tracking(0.5)
                            .foregroundColor(.white)
                        
                        Text(card.subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .tracking(0.2)
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // 箭頭按鈕
                    Button(action: {}) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 50, height: 50)
                            .background(Color(hex: "BFFF00"))
                            .cornerRadius(14)
                    }
                }
                .padding(20)
            }
        }
    }
}

// MARK: - 底部導航
struct BottomTabBar: View {
    var selectedTab: Int = 0
    var onTabChange: ((Int) -> Void)? = nil
    
    var body: some View {
        HStack {
            TabBarItem(icon: "house.fill", title: "Home", isSelected: selectedTab == 0) {
                onTabChange?(0)
            }
            
            Spacer()
            
            TabBarItem(icon: "heart", title: "", isSelected: selectedTab == 1) {
                onTabChange?(1)
            }
            
            Spacer()
            
            TabBarItem(icon: "chart.bar.fill", title: "", isSelected: selectedTab == 2) {
                onTabChange?(2)
            }
            
            Spacer()
            
            TabBarItem(icon: "person.circle", title: "", isSelected: selectedTab == 3) {
                onTabChange?(3)
            }
        }
        .padding(.horizontal, 30)
        .frame(height: 60)
        .background(Color.black)
        .cornerRadius(32)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

struct TabBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .foregroundColor(isSelected ? .black : .gray)
            .padding(.horizontal, !title.isEmpty ? 16 : 12)
            .frame(height: 40)
            .background(isSelected ? Color(hex: "BFFF00") : Color.clear)
            .cornerRadius(20)
        }
    }
}

#Preview {
    HomeView(authVM: AuthViewModel())
}
