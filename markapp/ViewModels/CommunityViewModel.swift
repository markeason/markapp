import Foundation
import Combine

class CommunityViewModel: ObservableObject {
    @Published var posts: [CommunityPost] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isRealtimeActive: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseManager = SupabaseManager.shared
    private var realtimeMonitorTimer: Timer?
    
    init() {
        setupSubscriptions()
        subscribeToRealtimeUpdates()
        startRealtimeMonitoring()
    }
    
    deinit {
        cleanup()
    }
    
    private func setupSubscriptions() {
        // Subscribe to post changes from Supabase
        supabaseManager.communityPostsPublisher
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.loadPosts()
                }
            }
            .store(in: &cancellables)
    }
    
    private func subscribeToRealtimeUpdates() {
        supabaseManager.subscribeToCommunityPosts()
    }
    
    private func startRealtimeMonitoring() {
        // Monitor connection status every 10 seconds
        realtimeMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                let wasActive = self.isRealtimeActive
                self.isRealtimeActive = self.supabaseManager.isSubscribedToCommunityPosts
                
                // Auto-reconnect if connection was lost
                if wasActive && !self.isRealtimeActive {
                    self.subscribeToRealtimeUpdates()
                }
            }
        }
    }
    
    private func cleanup() {
        realtimeMonitorTimer?.invalidate()
        realtimeMonitorTimer = nil
        
        // Correctly handle async function call
        Task {
            await supabaseManager.unsubscribeFromCommunityPosts()
        }
        
        cancellables.removeAll()
    }
    
    @MainActor
    func loadPosts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            posts = try await supabaseManager.getCommunityPosts()
            isLoading = false
        } catch {
            errorMessage = "Failed to load posts: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    @MainActor
    func createPost(title: String, body: String, bookID: UUID, sessionID: UUID, userID: String, userName: String) async {
        isLoading = true
        errorMessage = nil
        
        // Limit to 300 characters
        let limitedBody = body.count <= 300 ? body : String(body.prefix(300))
        
        // Use provided userName or fetch from profile if needed
        var finalUserName = userName
        
        if userName.isEmpty || userName.hasPrefix("Reader ") {
            do {
                if let userProfile = try await supabaseManager.getUserProfile(userId: userID) {
                    if !userProfile.name.isEmpty {
                        finalUserName = userProfile.name
                    }
                }
            } catch {
                // Continue with the provided userName if profile retrieval fails
            }
        }
        
        // Make sure we have a non-empty username
        finalUserName = finalUserName.isEmpty ? "Reader \(userID.prefix(4))" : finalUserName
        
        let post = CommunityPost(
            userID: userID,
            userName: finalUserName,
            bookID: bookID,
            sessionID: sessionID,
            title: title,
            body: limitedBody,
            createdAt: Date()
        )
        
        do {
            try await supabaseManager.saveCommunityPost(post)
            isLoading = false
            await loadPosts() // Refresh posts after creating
        } catch {
            errorMessage = "Failed to create post: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    @MainActor
    func getPostDetails(postID: String) async -> CommunityPost? {
        do {
            return try await supabaseManager.getCommunityPost(id: postID)
        } catch {
            errorMessage = "Failed to load post details: \(error.localizedDescription)"
            return nil
        }
    }
    
    @MainActor
    func deletePost(id: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await supabaseManager.deleteCommunityPost(id: id)
            isLoading = false
        } catch {
            errorMessage = "Failed to delete post: \(error.localizedDescription)"
            isLoading = false
        }
    }
} 