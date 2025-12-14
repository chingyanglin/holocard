import SwiftUI
import FirebaseAuth

struct ContentView: View {
    
    @StateObject private var authVM = AuthViewModel()
    @State private var currentPage = "launch"
    @State private var previousUser: User? = nil
    
    var body: some View {
        ZStack {
            if authVM.user != nil {
                // 已登入
                if currentPage == "profile" {
                    ProfileView(authVM: authVM, onBack: {
                        withAnimation {
                            currentPage = "home"
                        }
                    })
                } else if currentPage == "editor" {
                    EditorView(onBack: {
                        withAnimation {
                            currentPage = "home"
                        }
                    })
                } else {
                    HomeView(authVM: authVM, onNavigateToEditor: {
                        withAnimation {
                            currentPage = "editor"
                        }
                    }, onNavigateToProfile: {
                        withAnimation {
                            currentPage = "profile"
                        }
                    })
                }
            } else {
                // 未登入 → 顯示登入流程
                switch currentPage {
                case "signIn":
                    SignInView(authVM: authVM, onSignUp: {
                        withAnimation {
                            currentPage = "signUp"
                        }
                    })
                    
                case "signUp":
                    SignUpView(authVM: authVM, onSignIn: {
                        withAnimation {
                            currentPage = "signIn"
                        }
                    })
                    
                default:
                    LaunchView(onStart: {
                        withAnimation {
                            currentPage = "signIn"
                        }
                    })
                }
            }
        }
        .preferredColorScheme(.light)
        .onChange(of: authVM.user?.uid) { newUserId in
            if previousUser != nil && newUserId == nil {
                // 從登入變成登出
                currentPage = "launch"
            }
            previousUser = authVM.user
        }
        .onAppear {
            previousUser = authVM.user
        }
    }
}

#Preview {
    ContentView()
}
