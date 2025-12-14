//
//  UserService.swift
//  holocard
//
//  Created by ChingyangLin on 2025/12/13.
//

//
//  UserService.swift
//  holocard
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import UIKit
import Combine


class UserService: ObservableObject {
    
    static let shared = UserService()
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    
    // MARK: - 取得用戶資料
    func fetchUserProfile(userId: String) {
        isLoading = true
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("Error fetching user: \(error.localizedDescription)")
                    return
                }
                
                if let data = snapshot?.data() {
                    self.userProfile = UserProfile(
                        id: userId,
                        displayName: data["displayName"] as? String ?? "",
                        photoURL: data["photoURL"] as? String ?? "",
                        memberLevel: data["memberLevel"] as? String ?? "Noobie",
                        cardsCreated: data["cardsCreated"] as? Int ?? 0
                    )
                } else {
                    // 新用戶，建立預設資料
                    self.createDefaultProfile(userId: userId)
                }
            }
        }
    }
    
    // MARK: - 建立預設用戶資料
    private func createDefaultProfile(userId: String) {
        let defaultProfile = UserProfile(
            id: userId,
            displayName: "",
            photoURL: "",
            memberLevel: "Noobie",
            cardsCreated: 0
        )
        
        let data: [String: Any] = [
            "displayName": defaultProfile.displayName,
            "photoURL": defaultProfile.photoURL,
            "memberLevel": defaultProfile.memberLevel,
            "cardsCreated": defaultProfile.cardsCreated,
            "createdAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).setData(data) { error in
            if let error = error {
                print("Error creating profile: \(error.localizedDescription)")
            } else {
                DispatchQueue.main.async {
                    self.userProfile = defaultProfile
                }
            }
        }
    }
    
    // MARK: - 更新暱稱
    func updateDisplayName(userId: String, name: String, completion: @escaping (Bool) -> Void) {
        db.collection("users").document(userId).updateData([
            "displayName": name
        ]) { error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error updating name: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.userProfile?.displayName = name
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - 上傳頭像
    func uploadProfileImage(userId: String, image: UIImage, completion: @escaping (Bool) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.5) else {
            completion(false)
            return
        }
        
        let storageRef = storage.reference().child("profile_images/\(userId).jpg")
        
        isLoading = true
        
        storageRef.putData(imageData, metadata: nil) { _, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    completion(false)
                }
                return
            }
            
            // 取得下載 URL
            storageRef.downloadURL { url, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        print("Error getting URL: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    
                    guard let downloadURL = url else {
                        completion(false)
                        return
                    }
                    
                    // 更新 Firestore
                    self.db.collection("users").document(userId).updateData([
                        "photoURL": downloadURL.absoluteString
                    ]) { error in
                        if let error = error {
                            print("Error saving URL: \(error.localizedDescription)")
                            completion(false)
                        } else {
                            self.userProfile?.photoURL = downloadURL.absoluteString
                            completion(true)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 用戶資料模型
struct UserProfile {
    var id: String
    var displayName: String
    var photoURL: String
    var memberLevel: String
    var cardsCreated: Int
}
