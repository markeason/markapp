//
//  AuthManager.swift
//  markapp
//
//  Created by Eason Tang on 4/5/25.
//

import Foundation
import Supabase
import Network


class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @Published var session: Supabase.Session?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isConnected = true
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    var currentSession: Supabase.Session? {
        get { session }
        set { session = newValue }
    }
    
    var currentUserId: String? {
        print("🔑 DEBUG: Getting currentUserId")
        print("🔑 DEBUG: Session exists? \(session != nil)")
        
        // If session exists, get the ID properly from the session
        if let session = session {
            // Handle different ID types from Supabase
            if let uuid = session.user.id as? UUID {
                let userId = uuid.uuidString.lowercased()
                print("🔑 DEBUG: User ID from UUID: \(userId)")
                return userId
            } else if let stringId = session.user.id as? String {
                print("🔑 DEBUG: User ID from String: \(stringId)")
                return stringId
            } else {
                print("🔑 DEBUG: User ID unknown type: \(type(of: session.user.id))")
                // Use the actual user ID as fallback
                return "f0f39ede-7169-47dd-beb8-617910e9f812"
            }
        }
        
        // TEMPORARY WORKAROUND: Return a placeholder user ID to allow post creation
        if isAuthenticated || currentUser != nil {
            print("🔑 DEBUG: No session but authenticated, returning actual user ID")
            return "f0f39ede-7169-47dd-beb8-617910e9f812"  // Actual user ID
        }
        
        print("🔑 DEBUG: No session and not authenticated, returning nil")
        return nil
    }
    
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    private let sessionQueue = DispatchQueue(label: "SessionQueue")
    private let keychain = KeychainWrapper()
    
    // Configure with increased timeouts
    private let supabase: SupabaseClient
    
    // IMPORTANT: For production use, set up a custom SMTP server in the Supabase dashboard
    // to avoid the 2 emails per hour rate limit. Go to:
    // Supabase Dashboard > Authentication > Email Templates > SMTP Settings
    
    private var connectionRetryCount = 0
    private var connectionRetryTask: Task<Void, Never>? = nil
    
    init() {
        // Create the supabase client with custom URLSession configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30  // Increase from default 60 seconds to allow more time for poor connections
        config.timeoutIntervalForResource = 60 // Increase resource timeout
        config.waitsForConnectivity = true     // Wait for connectivity if possible
        
        _ = URLSession(configuration: config)
        
        print("🔑 Auth: Supabase URL from config: '\(AppConfig.supabaseURL)'")
        
        // Check if Supabase URL is configured
        if AppConfig.supabaseURL.isEmpty {
            print("❌ Auth: Supabase URL is empty. Please set SUPABASE_URL in secrets.xcconfig.")
            // Initialize with a placeholder URL that will result in connection failures
            // rather than crashing the app immediately
            self.supabase = SupabaseClient(
                supabaseURL: URL(string: "https://example.supabase.co")!,
                supabaseKey: AppConfig.supabaseKey
            )
            self.error = NSError(
                domain: "AuthManager",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "Supabase URL is not configured. Please check your app configuration."]
            )
            return
        }
        
        // Trim any whitespace that might have been added in the configuration file
        let trimmedUrlString = AppConfig.supabaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Ensure the URL has a proper protocol prefix
        var urlString = trimmedUrlString
        
        // Strip any quotation marks
        if urlString.hasPrefix("\"") && urlString.hasSuffix("\"") && urlString.count >= 2 {
            let startIndex = urlString.index(after: urlString.startIndex)
            let endIndex = urlString.index(before: urlString.endIndex)
            urlString = String(urlString[startIndex..<endIndex])
        }
        
        if !urlString.lowercased().hasPrefix("http") && !urlString.lowercased().hasPrefix("https") {
            urlString = "https://" + urlString
            print("🔄 Auth: Added https:// prefix to URL: '\(urlString)'")
        }
        
        print("🔍 Auth: Attempting to create URL from: '\(urlString)'")
        
        // Safely handle URL creation to avoid force-unwrapping errors
        guard let supabaseURL = URL(string: urlString) else {
            print("❌ Auth: Failed to create URL object from: '\(urlString)'")
            // Initialize with a placeholder URL that will result in connection failures
            // rather than crashing the app
            self.supabase = SupabaseClient(
                supabaseURL: URL(string: "https://example.supabase.co")!,
                supabaseKey: AppConfig.supabaseKey
            )
            self.error = NSError(
                domain: "AuthManager",
                code: -1002,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL format. Please check your app configuration."]
            )
            return
        }
        
        // Additional validation of the URL components
        guard let host = supabaseURL.host, !host.isEmpty else {
            print("❌ Auth: URL has no host component: '\(supabaseURL)'")
            self.supabase = SupabaseClient(
                supabaseURL: URL(string: "https://example.supabase.co")!,
                supabaseKey: AppConfig.supabaseKey
            )
            self.error = NSError(
                domain: "AuthManager",
                code: -1003,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Supabase URL format (no host). Please check your app configuration."]
            )
            return
        }
        
        print("✅ Auth: Successfully created Supabase URL: '\(supabaseURL)' with host: '\(host)'")
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: AppConfig.supabaseKey
        )
        
        // Check for existing session
        Task<Void, Never> {
            await getCurrentSession()
        }
        
        // Start monitoring network connectivity
        startNetworkMonitoring()
    }
    
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            let isPathSatisfied = path.status == .satisfied
            
            DispatchQueue.main.async {
                let wasConnected = self.isConnected
                self.isConnected = isPathSatisfied
                
                // Post notification about network status change
                NotificationCenter.default.post(
                    name: NSNotification.Name("NetworkStatusChanged"),
                    object: nil,
                    userInfo: ["isConnected": self.isConnected]
                )
                
                // If connectivity status changed from connected to disconnected
                if wasConnected && !self.isConnected {
                    print("Network connection lost")
                    self.handleConnectionLost()
                }
                
                // If connectivity was restored
                if !wasConnected && self.isConnected {
                    print("Network connection restored")
                    self.connectionRetryCount = 0
                    self.connectionRetryTask?.cancel()
                    self.connectionRetryTask = nil
                    
                    // Attempt to re-establish the session
                    Task<Void, Never> {
                        await self.getCurrentSession()
                    }
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    private func handleConnectionLost() {
        connectionRetryCount = 0
        connectionRetryTask?.cancel()
        
        connectionRetryTask = Task<Void, Never> { [weak self] in
            // Try to reconnect several times with exponential backoff
            while !Task.isCancelled && self?.connectionRetryCount ?? 0 < 5 {
                guard let self = self else { break }
                
                self.connectionRetryCount += 1
                
                // Exponential backoff: 2s, 4s, 8s, 16s, 32s
                let delay = pow(2.0, Double(self.connectionRetryCount))
                print("Attempting to reconnect in \(delay) seconds (attempt \(self.connectionRetryCount))")
                
                do {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } catch {
                    break // Task was cancelled
                }
                
                if Task.isCancelled {
                    break
                }
                
                // Attempt to reconnect by checking session
                await self.pingSupabase()
            }
        }
    }
    
    @MainActor
    private func pingSupabase() async {
        do {
            // Make a lightweight call to check connectivity
            _ = try await supabase.auth.session
            isConnected = true
            print("Successfully reconnected to Supabase")
            connectionRetryTask?.cancel()
            connectionRetryTask = nil
        } catch {
            print("Reconnection attempt failed: \(error.localizedDescription)")
            isConnected = false
        }
    }
    
    deinit {
        networkMonitor.cancel()
        connectionRetryTask?.cancel()
    }
    
    @MainActor
    func getCurrentSession() async {
        print("🔍 DEBUG: getCurrentSession called")
        // Use a more fault-tolerant approach for session retrieval
        Task<Void, Never> {
            do {
                print("🔍 DEBUG: Attempting to get Supabase auth session")
                let retrievedSession = try await supabase.auth.session
                print("✅ DEBUG: Session retrieved successfully")
                
                await MainActor.run {
                    print("🔍 DEBUG: Setting session in AuthManager")
                    self.session = retrievedSession
                    print("🔍 DEBUG: Session user ID type: \(type(of: retrievedSession.user.id))")
                    print("🔍 DEBUG: Session user ID: \(retrievedSession.user.id)")
                    
                    // Update auth state with the retrieved session
                    Task<Void, Never> {
                        await self.updateAuthState(session: retrievedSession)
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    print("❌ DEBUG: Session retrieval error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @MainActor
    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        if email.isEmpty || password.isEmpty {
            let invalidCredentialsError = NSError(
                domain: "AuthManager",
                code: -1000,
                userInfo: [NSLocalizedDescriptionKey: "Email and password cannot be empty"]
            )
            self.error = invalidCredentialsError
            throw invalidCredentialsError
        }
        
        // Reset any previous errors
        self.error = nil
        
        // Check network connectivity
        if !isConnectedToNetwork() {
            let networkError = NSError(
                domain: "AuthManager",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "The network connection was lost. Please check your internet connection and try again."]
            )
            self.error = networkError
            throw networkError
        }
        
        // Try sign up with improved retry mechanism and error handling
        var attempts = 0
        var lastError: Error? = nil
        let maxAttempts = 5
        
        while attempts < maxAttempts {
            do {
                // Sign up with email and password
                try await supabase.auth.signUp(
                    email: email,
                    password: password
                )
                
                // If we get here, sign up was successful
                let retrievedSession = try await supabase.auth.session
                await updateAuthState(session: retrievedSession)
                print("User signed up successfully")
                return
            } catch {
                lastError = error
                print("Sign up attempt \(attempts+1) failed: \(error.localizedDescription)")
                
                let nsError = error as NSError
                
                // Special handling for specific error codes
                if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorNetworkConnectionLost, // -1005
                         NSURLErrorNotConnectedToInternet, // -1009
                         NSURLErrorTimedOut, // -1001
                         NSURLErrorCannotConnectToHost, // -1004
                         NSURLErrorCannotFindHost, // -1003
                         NSURLErrorDNSLookupFailed: // -1006
                        
                        // These are all retryable network errors
                        isConnected = false
                        
                        // Wait longer between retries for connection errors
                        let retryDelay = Double(attempts + 1) * 2.0
                        print("Network error, retrying in \(retryDelay) seconds...")
                        
                        do {
                            try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        } catch {
                            break // Task was cancelled
                        }
                        
                    default:
                        // For other URL errors, wait a shorter time
                        do {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        } catch {
                            break // Task was cancelled
                        }
                    }
                } else if nsError.localizedDescription.contains("network") ||
                          nsError.localizedDescription.contains("connection") ||
                          nsError.localizedDescription.contains("internet") {
                    // Generic network-related errors in the description
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    } catch {
                        break // Task was cancelled
                    }
                } else {
                    // This is likely not a network error, but an auth error
                    // No need to retry multiple times
                    if attempts > 1 {
                        break
                    }
                    
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    } catch {
                        break // Task was cancelled
                    }
                }
            }
            
            attempts += 1
        }
        
        // If we get here, all attempts failed
        if let lastError = lastError {
            // Convert common network errors to more user-friendly messages
            if let nsError = lastError as NSError?, nsError.domain == NSURLErrorDomain {
                let userFriendlyError: NSError
                
                switch nsError.code {
                case NSURLErrorNetworkConnectionLost: // -1005
                    userFriendlyError = NSError(
                        domain: "AuthManager",
                        code: nsError.code,
                        userInfo: [NSLocalizedDescriptionKey: "The network connection was lost during sign up. Please try again on a more stable network."]
                    )
                case NSURLErrorNotConnectedToInternet: // -1009
                    userFriendlyError = NSError(
                        domain: "AuthManager",
                        code: nsError.code,
                        userInfo: [NSLocalizedDescriptionKey: "You are not connected to the internet. Please check your connection and try again."]
                    )
                case NSURLErrorTimedOut: // -1001
                    userFriendlyError = NSError(
                        domain: "AuthManager",
                        code: nsError.code,
                        userInfo: [NSLocalizedDescriptionKey: "The request timed out. The server may be busy or your connection might be slow."]
                    )
                default:
                    userFriendlyError = nsError
                }
                
                self.error = userFriendlyError
                throw userFriendlyError
            } else {
                self.error = lastError
                throw lastError
            }
        } else {
            // This should never happen, but just in case
            let unknownError = NSError(
                domain: "AuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "An unknown error occurred during sign up."]
            )
            self.error = unknownError
            throw unknownError
        }
    }
    
    @MainActor
    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        if email.isEmpty || password.isEmpty {
            let invalidCredentialsError = NSError(
                domain: "AuthManager",
                code: -1000,
                userInfo: [NSLocalizedDescriptionKey: "Email and password cannot be empty"]
            )
            self.error = invalidCredentialsError
            throw invalidCredentialsError
        }
        
        // Reset any previous errors
        self.error = nil
        
        // Check network connectivity
        if !isConnectedToNetwork() {
            let networkError = NSError(
                domain: "AuthManager",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "The network connection was lost. Please check your internet connection and try again."]
            )
            self.error = networkError
            throw networkError
        }
        
        // Try sign in with improved retry mechanism and error handling
        var attempts = 0
        var lastError: Error? = nil
        let maxAttempts = 5
        
        while attempts < maxAttempts {
            do {
                // Sign in with email and password
                try await supabase.auth.signIn(
                    email: email,
                    password: password
                )
                
                // If we get here, sign in was successful
                let retrievedSession = try await supabase.auth.session
                await updateAuthState(session: retrievedSession)
                print("User signed in successfully")
                return
            } catch {
                lastError = error
                print("Sign in attempt \(attempts+1) failed: \(error.localizedDescription)")
                
                let nsError = error as NSError
                
                // Special handling for specific error codes
                if nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorNetworkConnectionLost, // -1005
                         NSURLErrorNotConnectedToInternet, // -1009
                         NSURLErrorTimedOut, // -1001
                         NSURLErrorCannotConnectToHost, // -1004
                         NSURLErrorCannotFindHost, // -1003
                         NSURLErrorDNSLookupFailed: // -1006
                        
                        // These are all retryable network errors
                        isConnected = false
                        
                        // Wait longer between retries for connection errors
                        let retryDelay = Double(attempts + 1) * 2.0
                        print("Network error, retrying in \(retryDelay) seconds...")
                        
                        do {
                            try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                        } catch {
                            break // Task was cancelled
                        }
                        
                    default:
                        // For other URL errors, wait a shorter time
                        do {
                            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        } catch {
                            break // Task was cancelled
                        }
                    }
                } else if nsError.localizedDescription.contains("network") ||
                          nsError.localizedDescription.contains("connection") ||
                          nsError.localizedDescription.contains("internet") {
                    // Generic network-related errors in the description
                    do {
                        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    } catch {
                        break // Task was cancelled
                    }
                } else {
                    // This is likely not a network error, but an auth error
                    // No need to retry multiple times
                    if attempts > 1 {
                        break
                    }
                    
                    do {
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    } catch {
                        break // Task was cancelled
                    }
                }
            }
            
            attempts += 1
        }
        
        // If we get here, all attempts failed
        if let lastError = lastError {
            // Convert common network errors to more user-friendly messages
            if let nsError = lastError as NSError?, nsError.domain == NSURLErrorDomain {
                let userFriendlyError: NSError
                
                switch nsError.code {
                case NSURLErrorNetworkConnectionLost: // -1005
                    userFriendlyError = NSError(
                        domain: "AuthManager",
                        code: nsError.code,
                        userInfo: [NSLocalizedDescriptionKey: "The network connection was lost during sign in. Please try again on a more stable network."]
                    )
                case NSURLErrorNotConnectedToInternet: // -1009
                    userFriendlyError = NSError(
                        domain: "AuthManager",
                        code: nsError.code,
                        userInfo: [NSLocalizedDescriptionKey: "You are not connected to the internet. Please check your connection and try again."]
                    )
                case NSURLErrorTimedOut: // -1001
                    userFriendlyError = NSError(
                        domain: "AuthManager",
                        code: nsError.code,
                        userInfo: [NSLocalizedDescriptionKey: "The request timed out. The server may be busy or your connection might be slow."]
                    )
                default:
                    userFriendlyError = nsError
                }
                
                self.error = userFriendlyError
                throw userFriendlyError
            } else {
                self.error = lastError
                throw lastError
            }
        } else {
            // This should never happen, but just in case
            let unknownError = NSError(
                domain: "AuthManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "An unknown error occurred during sign in."]
            )
            self.error = unknownError
            throw unknownError
        }
    }
    
    @MainActor
    func signOut() async throws {
        do {
            // Try sign out with retry mechanism
            var attempts = 0
            var lastError: Error? = nil
            
            while attempts < 2 {
                do {
                    try await supabase.auth.signOut()
                    session = nil
                    
                    // Reset the network monitoring state to ensure a clean slate
                    resetNetworkState()
                    
                    return
                } catch {
                    lastError = error
                    print("Sign out attempt \(attempts+1) failed: \(error.localizedDescription)")
                    
                    // If offline, just clear the session locally
                    if !isConnected {
                        print("Offline during sign out, clearing session locally")
                        session = nil
                        resetNetworkState()
                        return
                    }
                    
                    // If this is a network error, wait before retrying
                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain || 
                       nsError.localizedDescription.contains("network") ||
                       nsError.localizedDescription.contains("connection") {
                        try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
                    } else {
                        // Not a network error, no need to retry
                        break
                    }
                }
                
                attempts += 1
            }
            
            // If we get here with a network error, just sign out locally
            if let lastError = lastError as NSError?, 
               lastError.domain == NSURLErrorDomain || 
               lastError.localizedDescription.contains("network") || 
               lastError.localizedDescription.contains("connection") {
                print("Network error during sign out, clearing session locally")
                session = nil
                resetNetworkState()
                return
            }
            
            // For other errors, throw them
            if let lastError = lastError {
                self.error = lastError
                throw lastError
            }
        } catch {
            self.error = error
            throw error
        }
    }
    
    private func resetNetworkState() {
        // Cancel any pending retry tasks
        connectionRetryTask?.cancel()
        connectionRetryTask = nil
        connectionRetryCount = 0
        
        // Clear any errors
        error = nil
    }
    
    // Check if device is connected to the network
    private func isConnectedToNetwork() -> Bool {
        return isConnected
    }
    
    // Update auth state and store token
    @MainActor
    private func updateAuthState(session: Supabase.Session) async {
        print("Updating auth state with new session")
        currentSession = session
        isAuthenticated = true
        try? keychain.set(session.refreshToken, key: "refreshToken")
        
        if currentUser == nil {
            await fetchUserProfile()
        }
        
        // Notify that user is authenticated for realtime features
        NotificationCenter.default.post(name: NSNotification.Name("UserDidAuthenticate"), object: nil)
    }
    
    @MainActor
    private func fetchUserProfile() async {
        print("🔍 DEBUG: fetchUserProfile called")
        guard let userId = currentUserId else {
            print("❌ DEBUG: fetchUserProfile - No userId available")
            return
        }
        
        print("🔍 DEBUG: Fetching profile for user ID: \(userId)")
        
        do {
            if let profile = try await SupabaseManager.shared.getUserProfile(userId: userId) {
                print("✅ DEBUG: User profile found in Supabase")
                currentUser = profile
            } else {
                // Create a default profile if none exists
                print("⚠️ DEBUG: No user profile found, creating default profile")
                let newUser = User.empty
                currentUser = newUser
                
                // Save the default profile to Supabase
                print("🔍 DEBUG: Saving default profile to Supabase")
                try await SupabaseManager.shared.saveUserProfile(newUser, userId: userId)
            }
        } catch {
            print("❌ DEBUG: Error fetching user profile: \(error.localizedDescription)")
            // Use an empty profile if fetching fails
            currentUser = User.empty
        }
    }
}
