import SwiftUI
import Supabase

@main
struct MarkAppApp: App {
    @StateObject private var authManager = AuthManager()
    
    init() {
        // Validate API keys on app startup
        AppConfig.validateAPIKeys()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentRoot()
                .environmentObject(authManager)
        }
    }
}

struct ContentRoot: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showNetworkAlert = false
    @State private var isSyncing = false
    
    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if authManager.session != nil {
                    if isSyncing {
                        SyncView()
                    } else {
                        MainTabView()
                            .environmentObject(authManager)
                    }
                } else {
                    SignInView()
                }
            }
            
            // Network connectivity banner
            if !authManager.isConnected {
                VStack {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        Text("No internet connection")
                            .font(.callout)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            showNetworkAlert = true
                        }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.red)
                    .transition(.move(edge: .top))
                }
                .zIndex(1)
                .animation(.easeInOut, value: authManager.isConnected)
            }
        }
        .onAppear {
            // Set the AuthManager in DataManager
            DataManager.shared.setAuthManager(authManager)
        }
        .onChange(of: authManager.session) { oldValue, newValue in
            // When the user logs in (session changes from nil to non-nil)
            if oldValue == nil && newValue != nil {
                performInitialSync()
            }
        }
        .alert("Network Unavailable", isPresented: $showNetworkAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please check your internet connection to continue using the app.")
        }
    }
    
    private func performInitialSync() {
        guard authManager.isConnected else {
            // Skip syncing if there's no network connection
            return
        }
        
        isSyncing = true
        
        Task {
            await DataManager.shared.performInitialSync()
            
            // After sync is complete, show the main interface
            await MainActor.run {
                isSyncing = false
            }
        }
    }
}

// A simple loading view shown during initial data sync
struct SyncView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
                .padding()
            
            Text("Syncing your data...")
                .font(.headline)
            
            Text("Please wait while we sync your books and reading sessions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}
