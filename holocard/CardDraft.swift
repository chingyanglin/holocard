//
//  CardDraft.swift
//  holocard
//

import SwiftUI
import Combine

// MARK: - 卡片草稿模型
struct CardDraft: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var status: DraftStatus = .saved
    
    // 卡片內容
    var imageURL: String?           // Firebase Storage 圖片 URL
    var localImagePath: String?     // 本地圖片檔案名稱（存在 Documents/DraftImages）
    var frameName: String?          // 選擇的外框名稱
    var shineEffectName: String?    // 選擇的閃卡效果名稱
    
    // 圖片調整
    var imageOffsetX: CGFloat = 0
    var imageOffsetY: CGFloat = 0
    var imageScale: CGFloat = 1.0
    
    // 卡片資訊
    var title: String?
    var description: String?
    
    static func == (lhs: CardDraft, rhs: CardDraft) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - 圖片儲存目錄
    static var imageDirectory: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let dir = paths[0].appendingPathComponent("DraftImages", isDirectory: true)
        
        // 確保目錄存在
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
    
    // MARK: - 讀取本地圖片
    var localImage: UIImage? {
        guard let path = localImagePath else { return nil }
        let url = CardDraft.imageDirectory.appendingPathComponent(path)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    
    // MARK: - 儲存圖片到檔案系統
    mutating func saveImage(_ image: UIImage) {
        let fileName = "\(id).jpg"
        let fileURL = CardDraft.imageDirectory.appendingPathComponent(fileName)
        
        // 壓縮並儲存
        if let data = image.jpegData(compressionQuality: 0.7) {
            do {
                try data.write(to: fileURL)
                self.localImagePath = fileName
            } catch {
                print("❌ 圖片儲存失敗: \(error)")
            }
        }
    }
    
    // MARK: - 刪除本地圖片
    func deleteLocalImage() {
        guard let path = localImagePath else { return }
        let url = CardDraft.imageDirectory.appendingPathComponent(path)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - 草稿狀態
enum DraftStatus: String, Codable, CaseIterable {
    case saved = "saved"
    case published = "published"
    
    var displayName: String {
        switch self {
        case .saved: return "Saved"
        case .published: return "Published"
        }
    }
}

// MARK: - 草稿管理器
final class DraftManager: ObservableObject {
    static let shared = DraftManager()
    
    @Published var drafts: [CardDraft] = []
    
    private let draftsKey = "holocard_drafts"
    
    init() {
        loadDrafts()
    }
    
    // 載入草稿
    func loadDrafts() {
        if let data = UserDefaults.standard.data(forKey: draftsKey),
           let decoded = try? JSONDecoder().decode([CardDraft].self, from: data) {
            self.drafts = decoded.sorted { $0.updatedAt > $1.updatedAt }
        }
    }
    
    // 儲存草稿
    func saveDraft(_ draft: CardDraft) {
        var newDraft = draft
        newDraft.updatedAt = Date()
        
        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = newDraft
        } else {
            drafts.insert(newDraft, at: 0)
        }
        
        persistDrafts()
    }
    
    // 刪除草稿
    func deleteDraft(_ draft: CardDraft) {
        draft.deleteLocalImage()  // 同時刪除本地圖片檔案
        drafts.removeAll { $0.id == draft.id }
        persistDrafts()
    }
    
    // 篩選草稿
    func drafts(for status: DraftStatus) -> [CardDraft] {
        drafts.filter { $0.status == status }
    }
    
    // 持久化（只存 metadata，不存圖片）
    private func persistDrafts() {
        if let encoded = try? JSONEncoder().encode(drafts) {
            UserDefaults.standard.set(encoded, forKey: draftsKey)
        }
    }
}
