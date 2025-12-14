//
//  SignUpView.swift
//  holocard
//
//  Created by ChingyangLin on 2025/12/12.
//
import SwiftUI

struct SignUpView: View {
    
    @ObservedObject var authVM: AuthViewModel
    
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    
    var onSignIn: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 返回按鈕
            HStack {
                Button(action: onSignIn) {
                    Image(systemName: "chevron.left")
                        .font(.body)
                        .foregroundColor(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.white)
                        .cornerRadius(18)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            
            Spacer().frame(height: 40)
            
            // 標題
            VStack(alignment: .leading, spacing: 4) {
                Text("Let's go! Register in")
                    .font(.title)
                    .fontWeight(.bold)
                Text("seconds.")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 32)
            
            // 社群登入按鈕
            HStack(spacing: 12) {
                SocialButton(imageName: "google", isSystemImage: false)
                SocialButton(imageName: "apple.logo", isSystemImage: true)
                SocialButton(imageName: "line", isSystemImage: false)
            }
            .padding(.horizontal, 24)
            
            // 分隔線
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or Register with")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .fixedSize()
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // 輸入框
            VStack(spacing: 16) {
                TextField("User name", text: $username)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                
                TextField("Email", text: $email)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                // 密碼
                HStack {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye" : "eye.slash")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // 確認密碼
                HStack {
                    if showConfirmPassword {
                        TextField("Confirm Password", text: $confirmPassword)
                    } else {
                        SecureField("Confirm Password", text: $confirmPassword)
                    }
                    Button(action: { showConfirmPassword.toggle() }) {
                        Image(systemName: showConfirmPassword ? "eye" : "eye.slash")
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 32)
            
            // 註冊按鈕
            Button(action: {
                authVM.signUp(email: email, password: password)
            }) {
                Text("Register")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "BFFF00"))
                    .cornerRadius(30)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // 登入連結
            HStack(spacing: 4) {
                Text("Already have an account?")
                    .foregroundColor(.gray)
                Button(action: onSignIn) {
                    Text("Log in")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
            }
            .font(.footnote)
            .padding(.bottom, 32)
        }
        .background(Color.white)
    }
}

#Preview {
    SignUpView(authVM: AuthViewModel(), onSignIn: {})
}
