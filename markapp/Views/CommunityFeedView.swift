import SwiftUI

struct CommunityFeedView: View {
    @StateObject private var viewModel = CommunityViewModel()
    @State private var showingCreatePost = false
    @State private var newPostsArrived = false
    @State private var realtimeIndicatorVisible = false
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.white.edgesIgnoringSafeArea(.all)
                
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                } else if let error = viewModel.errorMessage {
                    VStack {
                        Text("Error")
                            .font(.title)
                            .padding(.bottom, 4)
                        
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            Task {
                                await viewModel.loadPosts()
                            }
                        }
                        .padding(.top)
                    }
                } else if viewModel.posts.isEmpty {
                    VStack {
                        Text("No Posts Yet")
                            .font(.title)
                            .padding(.bottom, 4)
                        
                        Text("Be the first to share your reading session!")
                            .foregroundColor(.secondary)
                        
                        Button("Create Post") {
                            showingCreatePost = true
                        }
                        .padding(.top)
                    }
                } else {
                    VStack(spacing: 0) {
                        if realtimeIndicatorVisible {
                            HStack {
                                Circle()
                                    .fill(viewModel.isRealtimeActive ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                
                                Text(viewModel.isRealtimeActive ? "Live" : "Connecting...")
                                    .font(.caption)
                                    .foregroundColor(viewModel.isRealtimeActive ? .green : .orange)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemBackground))
                        }
                        
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.posts) { post in
                                    NavigationLink(destination: PostDetailView(postID: post.id.uuidString)) {
                                        PostCardView(post: post)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Community Feed")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCreatePost = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreatePost) {
                CreatePostView()
                    .environmentObject(viewModel)
                    .environmentObject(authManager)
            }
            .task {
                if viewModel.posts.isEmpty {
                    await viewModel.loadPosts()
                }
                
                // Show realtime indicator shortly after view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        realtimeIndicatorVisible = true
                    }
                }
            }
            .refreshable {
                await viewModel.loadPosts()
            }
            .onChange(of: viewModel.posts.count) { oldCount, newCount in
                if oldCount < newCount && oldCount > 0 {
                    // New posts arrived
                    highlightRealtimeIndicator()
                }
            }
        }
    }
    
    private func highlightRealtimeIndicator() {
        // Briefly pulse the realtime indicator to show new content has arrived
        withAnimation {
            newPostsArrived = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                newPostsArrived = false
            }
        }
    }
}

struct PostCardView: View {
    let post: CommunityPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(post.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("By \(post.userName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(post.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Book information with cover
            HStack(spacing: 12) {
                if let book = post.book, let coverUrl = book.coverURL, let url = URL(string: coverUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .foregroundColor(.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 90)
                    .cornerRadius(6)
                } else {
                    Rectangle()
                        .foregroundColor(.gray.opacity(0.3))
                        .frame(width: 60, height: 90)
                        .cornerRadius(6)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if let book = post.book {
                        Text(book.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(book.author)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Book details unavailable")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let session = post.session, let pagesRead = session.pagesRead {
                        Text("Read \(pagesRead) pages in \(session.formattedDuration)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Post content with limited characters
            Text(post.limitedBody)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            Text("Tap to see full post")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    CommunityFeedView()
        .environmentObject(AuthManager.shared)
} 