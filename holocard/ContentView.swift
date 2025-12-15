//
//  ContentView.swift
//  holocard
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    
    @StateObject private var authVM = AuthViewModel()
    @State private var currentPage = "launch"
    @State private var previousUser: User? = nil
    
    // 用於編輯現有草稿
    @State private var editingDraft: CardDraft? = nil
    
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
                    EditorView(
                        onBack: {
                            withAnimation {
                                currentPage = "home"
                                editingDraft = nil
                            }
                        },
                        existingDraft: editingDraft
                    )
                } else if currentPage == "drafts" {
                    DraftsView(
                        onSelectDraft: { draft in
                            editingDraft = draft
                            withAnimation {
                                currentPage = "editor"
                            }
                        },
                        onTabChange: { tab in
                            handleTabChange(tab)
                        }
                    )
                } else {
                    HomeView(authVM: authVM, onNavigateToEditor: {
                        editingDraft = nil
                        withAnimation {
                            currentPage = "editor"
                        }
                    }, onNavigateToProfile: {
                        withAnimation {
                            currentPage = "profile"
                        }
                    }, onNavigateToDrafts: {
                        withAnimation {
                            currentPage = "drafts"
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
                currentPage = "launch"
            }
            previousUser = authVM.user
        }
        .onAppear {
            previousUser = authVM.user
        }
    }
    
    private func handleTabChange(_ tab: Int) {
        switch tab {
        case 0:
            withAnimation { currentPage = "home" }
        case 1:
            withAnimation { currentPage = "drafts" }
        case 3:
            withAnimation { currentPage = "profile" }
        default:
            break
        }
    }
}

#Preview {
    ContentView()
}
