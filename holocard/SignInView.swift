import SwiftUI

struct SignInView: View {
    
    @ObservedObject var authVM: AuthViewModel
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    
    var onSignUp: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 返回按鈕
            HStack {
                Button(action: {}) {
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
                Text("Hey, welcome back!")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Good to see you again!")
                    .font(.title)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            
            Spacer().frame(height: 32)
            
            // 社群登入按鈕
            HStack(spacing: 12) {
                // Google
                SocialButton(imageName: "google", isSystemImage: false) {
                    authVM.signInWithGoogle()
                }
                // Apple
                SocialButton(imageName: "apple.logo", isSystemImage: true) {
                    // 之後加 Apple 登入
                }
                // LINE
                SocialButton(imageName: "line", isSystemImage: false) {
                    // 之後加 LINE 登入
                }
            }
            .padding(.horizontal, 24)
            
            // 分隔線
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                Text("or Login with")
                    .font(.footnote)
                    .foregroundColor(.gray)
                    .fixedSize()
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            
            // Email 輸入框
            VStack(spacing: 16) {
                TextField("Email", text: $email)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                
                // 密碼輸入框
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
            }
            .padding(.horizontal, 24)
            
            // 記住我 & 忘記密碼
            HStack {
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.square.fill")
                            .foregroundColor(Color(hex: "BFFF00"))
                        Text("Remember me")
                            .font(.footnote)
                            .foregroundColor(.black)
                    }
                }
                Spacer()
                Button(action: {}) {
                    Text("Forget password?")
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            
            Spacer().frame(height: 32)
            
            // 登入按鈕
            Button(action: {
                authVM.signIn(email: email, password: password)
            }) {
                Text("Login")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "BFFF00"))
                    .cornerRadius(30)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // 註冊連結
            HStack(spacing: 4) {
                Text("Don't have account?")
                    .foregroundColor(.gray)
                Button(action: onSignUp) {
                    Text("Sign Up")
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

// MARK: - 社群登入按鈕元件
struct SocialButton: View {
    let imageName: String
    var isSystemImage: Bool = false
    var action: () -> Void = {}
    
    var body: some View {
        Button(action: action) {
            Group {
                if isSystemImage {
                    Image(systemName: imageName)
                        .font(.title2)
                        .foregroundColor(.black)
                } else {
                    Image(imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

#Preview {
    SignInView(authVM: AuthViewModel(), onSignUp: {})
}
