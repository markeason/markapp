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
        print("🔄 DEBUG: createPost called in CommunityViewModel")
        print("🔄 DEBUG: Parameters - Title: \(title), UserID: \(userID)")
        print("🔄 DEBUG: Parameters - BookID: \(bookID), SessionID: \(sessionID)")
        
        isLoading = true
        errorMessage = nil
        
        // Limit to 300 characters
        let limitedBody = body.count <= 300 ? body : String(body.prefix(300))
        
        let post = CommunityPost(
            userID: userID,
            userName: userName,
            bookID: bookID,
            sessionID: sessionID,
            title: title,
            body: limitedBody,
            createdAt: Date()
        )
        
        print("🔄 DEBUG: Created post object with ID: \(post.id)")
        
        do {
            print("🔄 DEBUG: Calling supabaseManager.saveCommunityPost")
            try await supabaseManager.saveCommunityPost(post)
            print("✅ DEBUG: Post saved successfully")
            isLoading = false
            await loadPosts() // Refresh posts after creating
        } catch {
            print("❌ DEBUG: Error saving post: \(error.localizedDescription)")
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