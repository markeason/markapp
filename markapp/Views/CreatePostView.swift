import SwiftUI

struct CreatePostView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var viewModel: CommunityViewModel
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var title = ""
    @State private var postBody = ""
    @State private var selectedBookID: UUID?
    @State private var selectedSessionID: UUID?
    @State private var isLoading = false
    @State private var showingBookSelection = false
    @State private var showingSessionSelection = false
    @State private var selectedBook: Book?
    @State private var selectedSession: ReadingSession?
    @State private var allBooks: [Book] = []
    @State private var allSessions: [ReadingSession] = []
    @State private var errorMessage: String?
    
    private var characterCount: Int {
        postBody.count
    }
    
    private var charactersRemaining: Int {
        300 - characterCount
    }
    
    private var isFormValid: Bool {
        !title.isEmpty && 
        !postBody.isEmpty && 
        postBody.count <= 300 && 
        selectedBookID != nil && 
        selectedSessionID != nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Post Information")) {
                    TextField("Title", text: $title)
                    
                    VStack(alignment: .leading) {
                        ZStack(alignment: .topLeading) {
                            if postBody.isEmpty {
                                Text("Share your thoughts (max 300 characters)")
                                    .foregroundColor(.gray)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                            
                            TextEditor(text: $postBody)
                                .frame(minHeight: 100)
                                .opacity(postBody.isEmpty ? 0.25 : 1)
                        }
                        
                        Text("\(characterCount)/300 characters")
                            .font(.caption)
                            .foregroundColor(charactersRemaining >= 0 ? .gray : .red)
                    }
                }
                
                Section(header: Text("Select Book")) {
                    if let book = selectedBook {
                        HStack {
                            if let coverUrl = book.coverURL, let url = URL(string: coverUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                } placeholder: {
                                    Rectangle()
                                        .foregroundColor(.gray.opacity(0.3))
                                }
                                .frame(width: 50, height: 75)
                                .cornerRadius(4)
                            } else {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                                    .frame(width: 50, height: 75)
                                    .cornerRadius(4)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(book.title)
                                    .font(.headline)
                                
                                Text(book.author)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingBookSelection = true
                            }) {
                                Text("Change")
                            }
                        }
                    } else {
                        Button(action: {
                            showingBookSelection = true
                        }) {
                            Text("Select a Book")
                        }
                    }
                }
                
                Section(header: Text("Select Reading Session")) {
                    if let session = selectedSession {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(session.formattedDate)
                                    .font(.headline)
                                
                                if let pagesRead = session.pagesRead {
                                    Text("\(pagesRead) pages in \(session.formattedDuration)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Duration: \(session.formattedDuration)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                showingSessionSelection = true
                            }) {
                                Text("Change")
                            }
                        }
                    } else {
                        Button(action: {
                            showingSessionSelection = true
                        }) {
                            Text("Select a Reading Session")
                        }
                    }
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Create Post")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") {
                        createPost()
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .sheet(isPresented: $showingBookSelection) {
                BookSelectionSheet(books: allBooks, selectedBook: $selectedBook, selectedBookID: $selectedBookID)
            }
            .sheet(isPresented: $showingSessionSelection) {
                SessionSelectionSheet(sessions: allSessions, selectedSession: $selectedSession, selectedSessionID: $selectedSessionID)
            }
            .onAppear {
                loadUserData()
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
        }
    }
    
    private func loadUserData() {
        // Load user books and sessions
        Task {
            do {
                // Load books and sessions from Supabase
                let dataManager = DataManager.shared
                allBooks = dataManager.loadBooks()
                
                // Filter sessions by book if a book is selected
                if let selectedBookID = selectedBookID {
                    allSessions = dataManager.loadSessions().filter { $0.bookID == selectedBookID }
                } else {
                    allSessions = dataManager.loadSessions()
                }
            } catch {
                errorMessage = "Failed to load books and sessions: \(error.localizedDescription)"
            }
        }
    }
    
    private func createPost() {
        print("📱 DEBUG: createPost button pressed in CreatePostView")
        print("📱 DEBUG: selectedBookID exists? \(selectedBookID != nil)")
        print("📱 DEBUG: selectedSessionID exists? \(selectedSessionID != nil)")
        print("📱 DEBUG: AuthManager authenticated? \(authManager.isAuthenticated)")
        print("📱 DEBUG: AuthManager currentUser exists? \(authManager.currentUser != nil)")
        print("📱 DEBUG: Attempting to get authManager.currentUserId...")
        
        // Get the required IDs
        guard let bookID = selectedBookID, 
              let sessionID = selectedSessionID else {
            print("❌ DEBUG: Missing book or session ID")
            errorMessage = "Please select a book and reading session"
            return
        }
        
        // Ensure user is authenticated
        guard authManager.isAuthenticated else {
            print("❌ DEBUG: User is not authenticated")
            errorMessage = "Please sign in to create a post"
            return
        }
        
        // Get current user ID
        guard let userID = authManager.currentUserId else {
            print("❌ DEBUG: No valid user ID available")
            errorMessage = "Unable to create post: User ID not found"
            return
        }
        
        print("📱 DEBUG: Using authenticated userID: \(userID)")
        createPostWithUserId(userID)
    }
    
    private func createPostWithUserId(_ userID: String) {
        isLoading = true
        
        Task {
            do {
                print("📱 DEBUG: Calling viewModel.createPost")
                
                // Get or create the user's profile
                var userName = "Reader \(userID.prefix(4))" // Default fallback
                
                // Try to get existing profile
                if let profile = try? await SupabaseManager.shared.getUserProfile(userId: userID) {
                    if !profile.name.isEmpty {
                        userName = profile.name
                        print("📱 DEBUG: Got name from profile: '\(userName)'")
                    } else {
                        // Profile exists but has no name, update it
                        print("📱 DEBUG: Profile exists but has no name, updating it")
                        let defaultName = authManager.currentUser?.name ?? userName
                        let updatedUser = User(
                            name: defaultName,
                            location: profile.location,
                            joinDate: profile.joinDate,
                            profilePhotoData: profile.profilePhotoData
                        )
                        try await SupabaseManager.shared.saveUserProfile(updatedUser, userId: userID)
                        userName = defaultName
                        print("📱 DEBUG: Updated profile with name: '\(userName)'")
                    }
                } else {
                    // No profile found, create one
                    print("📱 DEBUG: No profile found, creating new profile")
                    let defaultName = authManager.currentUser?.name ?? userName
                    let newUser = User(
                        name: defaultName,
                        location: "",
                        joinDate: Date(),
                        profilePhotoData: nil
                    )
                    try await SupabaseManager.shared.saveUserProfile(newUser, userId: userID)
                    userName = defaultName
                    print("📱 DEBUG: Created new profile with name: '\(userName)'")
                }
                
                print("📱 DEBUG: Final userName for post: '\(userName)'")
                
                await viewModel.createPost(
                    title: title,
                    body: postBody,
                    bookID: selectedBookID!,
                    sessionID: selectedSessionID!,
                    userID: userID,
                    userName: userName
                )
                
                print("📱 DEBUG: Post creation completed, dismissing view")
                await MainActor.run {
                    isLoading = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("❌ DEBUG: Error in CreatePostView: \(error.localizedDescription)")
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to create post: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct BookSelectionSheet: View {
    let books: [Book]
    @Binding var selectedBook: Book?
    @Binding var selectedBookID: UUID?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(books) { book in
                    HStack {
                        if let coverUrl = book.coverURL, let url = URL(string: coverUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            } placeholder: {
                                Rectangle()
                                    .foregroundColor(.gray.opacity(0.3))
                            }
                            .frame(width: 40, height: 60)
                            .cornerRadius(4)
                        } else {
                            Rectangle()
                                .foregroundColor(.gray.opacity(0.3))
                                .frame(width: 40, height: 60)
                                .cornerRadius(4)
                        }
                        
                        VStack(alignment: .leading) {
                            Text(book.title)
                                .font(.headline)
                            
                            Text(book.author)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedBook = book
                        selectedBookID = book.id
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Select Book")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

struct SessionSelectionSheet: View {
    let sessions: [ReadingSession]
    @Binding var selectedSession: ReadingSession?
    @Binding var selectedSessionID: UUID?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sessions) { session in
                    VStack(alignment: .leading) {
                        Text(session.formattedDate)
                            .font(.headline)
                        
                        if let pagesRead = session.pagesRead {
                            Text("\(pagesRead) pages in \(session.formattedDuration)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Duration: \(session.formattedDuration)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let summary = session.aiSummary, !summary.isEmpty {
                            Text("Has summary")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.top, 4)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSession = session
                        selectedSessionID = session.id
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationTitle("Select Reading Session")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CreatePostView()
        .environmentObject(CommunityViewModel())
        .environmentObject(AuthManager.shared)
} 