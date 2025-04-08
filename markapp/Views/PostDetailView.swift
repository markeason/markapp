import SwiftUI
import Combine

struct PostDetailView: View {
    let postID: String
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var viewModel = CommunityViewModel()
    @State private var post: CommunityPost?
    @State private var isLoading = true
    @State private var showingDeleteAlert = false
    @State private var showingUpdateIndicator = false
    @Environment(\.presentationMode) var presentationMode
    
    // Subscription to real-time updates
    @State private var cancellable: AnyCancellable?
    
    // Public initializer for preview and navigation
    init(postID: String) {
        self.postID = postID
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                            .padding()
                        Spacer()
                    }
                } else if let post = post {
                    // Post Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(post.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if showingUpdateIndicator {
                                Text("Updated")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                        
                        HStack {
                            Text("By \(post.userName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(post.formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Book Information
                    if let book = post.book {
                        HStack(alignment: .top, spacing: 16) {
                            if let coverUrl = book.coverURL, let url = URL(string: coverUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                }
                                .frame(width: 100, height: 150)
                                .cornerRadius(8)
                            } else {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: 100, height: 150)
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.title)
                                    .font(.headline)
                                
                                Text("by \(book.author)")
                                    .font(.subheadline)
                                
                                if let totalPages = book.totalPages {
                                    Text("\(totalPages) pages")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let session = post.session {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let pagesRead = session.pagesRead {
                                            Text("Pages read: \(pagesRead)")
                                                .font(.subheadline)
                                        }
                                        
                                        Text("Reading time: \(session.formattedDuration)")
                                            .font(.subheadline)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Post Content
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Comments")
                            .font(.headline)
                        
                        Text(post.body)
                            .font(.body)
                    }
                    .padding(.horizontal)
                    
                    // Reading Summary
                    if let session = post.session, let summary = session.aiSummary, !summary.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Reading Summary")
                                .font(.headline)
                                .padding(.top)
                            
                            Text(summary)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Delete Button (only for post owner)
                    if post.userID == authManager.currentUserId {
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Post")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                            .padding(.top, 20)
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Text("Post not found")
                            .font(.title)
                        
                        Button("Go Back") {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Post Details")
        .task {
            // Initial load
            await loadPostDetails()
            
            // Set up subscription to update when posts change
            setupRealtimeUpdates()
        }
        .onDisappear {
            // Clean up subscription
            cancellable?.cancel()
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text("Delete Post"),
                message: Text("Are you sure you want to delete this post? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    Task {
                        await deletePost()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func setupRealtimeUpdates() {
        cancellable = SupabaseManager.shared.communityPostsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak viewModel, postID] _ in
                // When any post changes, check if our post was affected
                Task { @MainActor in
                    guard let viewModel = viewModel else { return }
                    let updatedPost = await viewModel.getPostDetails(postID: postID)
                    if updatedPost != nil {
                        NotificationCenter.default.post(name: Notification.Name("PostUpdated-\(postID)"), object: updatedPost)
                    }
                }
            }
        
        // Listen for our specific post update notification
        let notificationCancellable = NotificationCenter.default.publisher(for: Notification.Name("PostUpdated-\(postID)"))
            .receive(on: RunLoop.main)
            .sink { notification in
                if let updatedPost = notification.object as? CommunityPost {
                    let oldPost = self.post
                    self.post = updatedPost
                    
                    // Show indicator if the post was updated
                    if oldPost != nil && oldPost != updatedPost {
                        self.showUpdateIndicator()
                    }
                }
            }
        
        // Store this cancellable too
        self.cancellable = AnyCancellable {
            notificationCancellable.cancel()
            self.cancellable?.cancel()
        }
    }
    
    private func showUpdateIndicator() {
        withAnimation {
            showingUpdateIndicator = true
        }
        
        // Hide the indicator after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showingUpdateIndicator = false
            }
        }
    }
    
    private func loadPostDetails() async {
        isLoading = true
        post = await viewModel.getPostDetails(postID: postID)
        isLoading = false
    }
    
    private func deletePost() async {
        guard let post = post else { return }
        await viewModel.deletePost(id: post.id.uuidString)
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    NavigationView {
        PostDetailView(postID: "123")
            .environmentObject(AuthManager.shared)
    }
} 
