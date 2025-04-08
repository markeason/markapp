import SwiftUI
import Supabase

@main
struct MarkAppApp: App {
    // Define a lazy var for the AuthManager so we can initialize it after config
    @StateObject private var authManager: AuthManager
    
    init() {
        // Preload configuration values statically before creating any managers
        MarkAppApp.preloadConfigurationValues()
        
        // Validate API keys 
        AppConfig.validateAPIKeys()
        
        // Initialize AuthManager after config is loaded
        let manager = AuthManager.shared
        _authManager = StateObject(wrappedValue: manager)
        
        // Set up other features
        setupRealtimeFeatures()
    }
    
    /// Preload and cache all configuration values before app initialization
    private static func preloadConfigurationValues() {
        // Ensure config is fully loaded before initializing any managers
        print("🔄 App: Preloading configuration values...")
        let supabaseUrl = AppConfig.supabaseURL 
        let supabaseKey = AppConfig.supabaseKey
        let openAIKey = AppConfig.openAIAPIKey
        print("🔄 App: Finished preloading configuration")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentRoot()
                .environmentObject(authManager)
        }
    }
    
    private func setupRealtimeFeatures() {
        // Setup Supabase realtime features
        
        // Handle user authentication
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("UserDidAuthenticate"),
            object: nil,
            queue: .main) { _ in
                SupabaseManager.shared.subscribeToCommunityPosts()
            }
        
        // Handle app lifecycle
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main) { _ in
                Task {
                    await SupabaseManager.shared.unsubscribeFromCommunityPosts()
                }
            }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main) { _ in
                if AuthManager.shared.isAuthenticated {
                    SupabaseManager.shared.subscribeToCommunityPosts()
                }
            }
        
        // Handle network changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NetworkStatusChanged"),
            object: nil,
            queue: .main) { notification in
                if let isConnected = notification.userInfo?["isConnected"] as? Bool, 
                   isConnected && AuthManager.shared.isAuthenticated {
                    SupabaseManager.shared.subscribeToCommunityPosts()
                }
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
