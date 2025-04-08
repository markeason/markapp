import Foundation
import Supabase
import Combine

// At the top of the file, add these typealias declarations to help with the Realtime API
typealias RealtimeEvent = PostgresAction

// Profile entity for Supabase
struct ProfileRecord: Encodable {
    let id: String
    let name: String
    let location: String
    let join_date: String
    let profile_photo_url: String?
}

// Community Post entity for Supabase
struct CommunityPostRecord: Encodable {
    let id: String
    let user_id: String
    let book_id: String
    let session_id: String
    let title: String
    let body: String
    let created_at: String
}

// Community Post response struct for decoding
struct CommunityPostResponse: Decodable {
    let id: String
    let user_id: String
    let book_id: String
    let session_id: String
    let title: String
    let body: String
    let created_at: String
}

// Profile response struct for decoding
struct ProfileResponse: Decodable {
    let id: String
    let name: String?
    let location: String?
    let join_date: String?
    let profile_photo_url: String?
}

// Book entity for Supabase
struct BookRecord: Encodable {
    let id: String
    let user_id: String
    let isbn: String
    let title: String
    let author: String
    let cover_url: String?
    let current_page: Int
    let total_pages: Int?
}

// Book response struct for decoding
struct BookResponse: Decodable {
    let id: String
    let user_id: String
    let isbn: String
    let title: String
    let author: String
    let cover_url: String?
    let current_page: Int?
    let total_pages: Int?
}

// Reading Session entity for Supabase
struct ReadingSessionRecord: Encodable {
    let id: String
    let user_id: String
    let book_id: String
    let start_time: String
    let end_time: String?
    let start_page: Int
    let end_page: Int?
    let ai_summary: String?
    let transcript: String?
}

// Reading Session response struct for decoding
struct SessionResponse: Decodable {
    let id: String
    let user_id: String
    let book_id: String
    let start_time: String
    let end_time: String?
    let start_page: Int
    let end_page: Int?
    let ai_summary: String?
    let transcript: String?
}

class SupabaseManager {
    static let shared = SupabaseManager()
    
    // Use the same Supabase client configuration as AuthManager
    private let supabase: SupabaseClient
    
    // Publishers for data changes
    var booksPublisher = PassthroughSubject<Void, Never>()
    var sessionsPublisher = PassthroughSubject<Void, Never>()
    var userPublisher = PassthroughSubject<Void, Never>()
    var communityPostsPublisher = PassthroughSubject<Void, Never>()
    
    // Realtime subscription references
    private var communityPostsSubscription: RealtimeChannelV2?
    private var isRealtimeConnected = false
    
    private init() {
        print("🔑 SupabaseManager: Supabase URL from config: '\(AppConfig.supabaseURL)'")
        
        // Check if Supabase URL is configured
        if AppConfig.supabaseURL.isEmpty {
            print("❌ SupabaseManager: Supabase URL is empty. Please set SUPABASE_URL in secrets.xcconfig.")
            // Initialize with a placeholder URL that will result in connection failures
            // rather than crashing the app immediately
            self.supabase = SupabaseClient(
                supabaseURL: URL(string: "https://example.supabase.co")!,
                supabaseKey: AppConfig.supabaseKey
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
            print("🔄 SupabaseManager: Added https:// prefix to URL: '\(urlString)'")
        }
        
        print("🔍 SupabaseManager: Attempting to create URL from: '\(urlString)'")
        
        // Safely handle URL creation to avoid force-unwrapping errors
        guard let supabaseURL = URL(string: urlString) else {
            print("❌ SupabaseManager: Failed to create URL object from: '\(urlString)'")
            // Initialize with a placeholder URL that will result in connection failures
            // rather than crashing the app
            self.supabase = SupabaseClient(
                supabaseURL: URL(string: "https://example.supabase.co")!,
                supabaseKey: AppConfig.supabaseKey
            )
            return
        }
        
        // Additional validation of the URL components
        guard let host = supabaseURL.host, !host.isEmpty else {
            print("❌ SupabaseManager: URL has no host component: '\(supabaseURL)'")
            self.supabase = SupabaseClient(
                supabaseURL: URL(string: "https://example.supabase.co")!,
                supabaseKey: AppConfig.supabaseKey
            )
            return
        }
        
        print("✅ SupabaseManager: Successfully created Supabase URL: '\(supabaseURL)' with host: '\(host)'")
        self.supabase = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: AppConfig.supabaseKey
        )
    }
    
    // MARK: - Profile Methods
    
    func saveUserProfile(_ user: User, userId: String) async throws {
        let dateFormatter = ISO8601DateFormatter()
        
        let userProfile = ProfileRecord(
            id: userId,
            name: user.name,
            location: user.location,
            join_date: dateFormatter.string(from: user.joinDate),
            profile_photo_url: user.profilePhotoData != nil ? "has_photo" : nil
        )
        
        print("Preparing to save profile for user \(userId)")
        print("Name: \(user.name), Location: \(user.location)")
        
        // Check if user profile exists
        let result: PostgrestResponse<[ProfileResponse]>
        do {
            result = try await supabase
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
        } catch {
            print("Error checking if profile exists: \(error.localizedDescription)")
            throw error
        }
        
        // Parse the response data
        let profilesArray = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        let profileExists = !profilesArray.isEmpty
        
        // Update or insert based on existence check
        do {
            if profileExists {
                print("Updating existing profile for user \(userId)")
                try await supabase
                    .from("profiles")
                    .update(userProfile)
                    .eq("id", value: userId)
                    .execute()
                print("Profile update successful")
            } else {
                print("Creating new profile for user \(userId)")
                try await supabase
                    .from("profiles")
                    .insert(userProfile)
                    .execute()
                print("Profile creation successful")
            }
        } catch {
            print("Error saving profile: \(error.localizedDescription)")
            throw error
        }
        
        // If there's a profile photo, save it to storage
        if let photoData = user.profilePhotoData {
            do {
                try await saveProfilePhoto(userId: userId, photoData: photoData)
                print("Profile photo saved successfully")
            } catch {
                print("Warning: Profile photo could not be saved: \(error.localizedDescription)")
                // Continue anyway since the profile itself was saved
            }
        }
        
        // Notify subscribers that user data has changed
        userPublisher.send()
    }
    
    private func parseDataResponse<T>(_ resultData: Any, defaultValue: T) -> T {
        print("Response data type: \(type(of: resultData))")
        
        if let data = resultData as? Data {
            do {
                let json = try JSONSerialization.jsonObject(with: data)
                print("Parsed JSON: \(json)")
                return json as? T ?? defaultValue
            } catch {
                print("Error parsing data response: \(error)")
                return defaultValue
            }
        }
        
        // If data is already the correct type, return it
        return resultData as? T ?? defaultValue
    }
    
    func getUserProfile(userId: String) async throws -> User? {
        let result = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
        
        print("Supabase data type: \(type(of: result.data))")
        
        // Parse the response data
        let profilesArray = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        
        if let profile = profilesArray.first {
            // Parse the data
            let name = profile["name"] as? String ?? ""
            let location = profile["location"] as? String ?? ""
            
            // Parse date
            let joinDate: Date
            if let dateString = profile["join_date"] as? String, 
               let parsedDate = ISO8601DateFormatter().date(from: dateString) {
                joinDate = parsedDate
            } else {
                joinDate = Date()
            }
            
            // Get profile photo if it exists
            var profilePhotoData: Data? = nil
            if profile["profile_photo_url"] != nil {
                do {
                    profilePhotoData = try await getProfilePhoto(userId: userId)
                } catch {
                    print("Error fetching profile photo: \(error.localizedDescription)")
                }
            }
            
            return User(
                name: name,
                location: location,
                joinDate: joinDate,
                profilePhotoData: profilePhotoData
            )
        }
        
        return nil
    }
    
    private func saveProfilePhoto(userId: String, photoData: Data) async throws {
        // Save to Supabase Storage
        let lowercaseId = userId.lowercased()
        let filePath = "profile_photos/\(lowercaseId).jpg"
        let bucketName = "private-user-content"
        
        do {
            print("Attempting to upload profile photo for user \(userId)")
            print("Using bucket: \(bucketName)")
            print("File path: \(filePath)")
            
            // Ensure we have auth session when uploading
            _ = try await supabase.auth.session
            
            // Upload the file to the bucket
            try await supabase.storage
                .from(bucketName)
                .upload(
                    filePath,
                    data: photoData,
                    options: FileOptions(contentType: "image/jpeg", upsert: true)
                )
            print("Profile photo uploaded successfully")
        } catch {
            print("Error in profile photo upload process: \(error.localizedDescription)")
            throw error
        }
    }
    
    private func getProfilePhoto(userId: String) async throws -> Data? {
        let lowercaseId = userId.lowercased()
        let filePath = "profile_photos/\(lowercaseId).jpg"
        let bucketName = "private-user-content"
        
        do {
            print("Attempting to download profile photo for user \(userId)")
            
            // Ensure we have auth session when downloading
            _ = try await supabase.auth.session
            
            do {
                let data = try await supabase.storage
                    .from(bucketName)
                    .download(path: filePath)
                
                print("Profile photo downloaded successfully")
                return data
            } catch {
                if error.localizedDescription.contains("Object not found") {
                    print("Profile photo not found for user \(userId)")
                    return nil
                } else {
                    print("Error downloading profile photo: \(error.localizedDescription)")
                    return nil
                }
            }
        } catch {
            print("Error in profile photo download process: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Book Methods
    
    func saveBook(_ book: Book, userId: String) async throws {
        let bookRecord = BookRecord(
            id: book.id.uuidString,
            user_id: userId,
            isbn: book.isbn,
            title: book.title,
            author: book.author,
            cover_url: book.coverURL,
            current_page: book.currentPage,
            total_pages: book.totalPages
        )
        
        // First, check if a book with this ISBN already exists for this user
        let isbnCheckResult = try await supabase
            .from("books")
            .select()
            .eq("isbn", value: book.isbn)
            .eq("user_id", value: userId)
            .execute()
        
        // Parse the response data
        let existingBooks = parseDataResponse(isbnCheckResult.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        let existingBookId = existingBooks.first?["id"] as? String
        
        if let existingId = existingBookId {
            // Update the existing book with this ISBN
            print("Updating existing book with ISBN \(book.isbn), ID: \(existingId)")
            try await supabase
                .from("books")
                .update(bookRecord)
                .eq("id", value: existingId)
                .eq("user_id", value: userId)
                .execute()
        } else {
            // Check if book with this ID exists
            let idCheckResult = try await supabase
                .from("books")
                .select()
                .eq("id", value: book.id.uuidString)
                .eq("user_id", value: userId)
                .execute()
            
            // Parse the response data
            let idBooks = parseDataResponse(idCheckResult.data, defaultValue: [[String: Any]]()) as [[String: Any]]
            let bookExists = !idBooks.isEmpty
            
            if bookExists {
                // Update the book with this ID
                print("Updating book with ID \(book.id.uuidString)")
                try await supabase
                    .from("books")
                    .update(bookRecord)
                    .eq("id", value: book.id.uuidString)
                    .eq("user_id", value: userId)
                    .execute()
            } else {
                // Insert new book
                print("Inserting new book with ISBN \(book.isbn)")
                try await supabase
                    .from("books")
                    .insert(bookRecord)
                    .execute()
            }
        }
        
        booksPublisher.send()
    }
    
    func getBooks(userId: String) async throws -> [Book] {
        let result = try await supabase
            .from("books")
            .select()
            .eq("user_id", value: userId)
            .execute()
        
        // Debug the response format
        print("Books response type: \(type(of: result.data))")
        
        // Parse the response data
        let booksArray = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        
        return booksArray.compactMap { bookData in
            guard let idString = bookData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let isbn = bookData["isbn"] as? String,
                  let title = bookData["title"] as? String,
                  let author = bookData["author"] as? String else {
                return nil
            }
            
            let coverURL = bookData["cover_url"] as? String
            let currentPage = bookData["current_page"] as? Int ?? 0
            let totalPages = bookData["total_pages"] as? Int
            
            return Book(
                id: id,
                isbn: isbn,
                title: title,
                author: author,
                coverURL: coverURL,
                currentPage: currentPage,
                totalPages: totalPages
            )
        }
    }
    
    func deleteBook(bookId: UUID, userId: String) async throws {
        // First delete related sessions
        try await supabase
            .from("reading_sessions")
            .delete()
            .eq("book_id", value: bookId.uuidString)
            .eq("user_id", value: userId)
            .execute()
        
        // Then delete the book
        try await supabase
            .from("books")
            .delete()
            .eq("id", value: bookId.uuidString)
            .eq("user_id", value: userId)
            .execute()
        
        booksPublisher.send()
        sessionsPublisher.send()
    }
    
    // MARK: - Reading Session Methods
    
    func getSessions(userId: String, bookId: UUID? = nil) async throws -> [ReadingSession] {
        var query = supabase
            .from("reading_sessions")
            .select()
            .eq("user_id", value: userId)
        
        // Filter by book ID if provided
        if let bookId = bookId {
            query = query.eq("book_id", value: bookId.uuidString)
        }
        
        let result = try await query.execute()
        
        // Debug the response format
        print("Sessions response type: \(type(of: result.data))")
        
        // Parse the response data
        let sessionsArray = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        
        return sessionsArray.compactMap { sessionData in
            guard let idString = sessionData["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let bookIdString = sessionData["book_id"] as? String,
                  let bookId = UUID(uuidString: bookIdString),
                  let startTimeString = sessionData["start_time"] as? String,
                  let startTime = ISO8601DateFormatter().date(from: startTimeString),
                  let startPage = sessionData["start_page"] as? Int else {
                return nil
            }
            
            // Parse optional fields
            var endTime: Date? = nil
            if let endTimeString = sessionData["end_time"] as? String {
                endTime = ISO8601DateFormatter().date(from: endTimeString)
            }
            
            let endPage = sessionData["end_page"] as? Int
            let aiSummary = sessionData["ai_summary"] as? String
            let transcript = sessionData["transcript"] as? String
            
            return ReadingSession(
                id: id,
                bookID: bookId,
                startTime: startTime,
                endTime: endTime,
                startPage: startPage,
                endPage: endPage,
                aiSummary: aiSummary,
                transcript: transcript
            )
        }
    }
    
    func saveSession(_ session: ReadingSession, userId: String) async throws {
        let dateFormatter = ISO8601DateFormatter()
        
        // Create a session record that conforms to Encodable
        let sessionRecord = ReadingSessionRecord(
            id: session.id.uuidString,
            user_id: userId,
            book_id: session.bookID.uuidString,
            start_time: dateFormatter.string(from: session.startTime),
            end_time: session.endTime != nil ? dateFormatter.string(from: session.endTime!) : nil,
            start_page: session.startPage,
            end_page: session.endPage,
            ai_summary: session.aiSummary,
            transcript: session.transcript
        )
        
        // Check if session exists
        let result = try await supabase
            .from("reading_sessions")
            .select()
            .eq("id", value: session.id.uuidString)
            .eq("user_id", value: userId)
            .execute()
        
        // Parse the response data
        let existingSessions = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        let sessionExists = !existingSessions.isEmpty
        
        // Update or insert based on existence check
        if sessionExists {
            print("Updating existing session with ID \(session.id.uuidString)")
            try await supabase
                .from("reading_sessions")
                .update(sessionRecord)
                .eq("id", value: session.id.uuidString)
                .eq("user_id", value: userId)
                .execute()
        } else {
            print("Creating new session with ID \(session.id.uuidString)")
            try await supabase
                .from("reading_sessions")
                .insert(sessionRecord)
                .execute()
        }
        
        sessionsPublisher.send()
    }
    
    func deleteSession(sessionId: UUID, userId: String) async throws {
        try await supabase
            .from("reading_sessions")
            .delete()
            .eq("id", value: sessionId.uuidString)
            .eq("user_id", value: userId)
            .execute()
        
        sessionsPublisher.send()
    }
    
    // MARK: - Community Post Methods
    
    func subscribeToCommunityPosts() {
        print("Realtime subscription temporarily disabled")
        isRealtimeConnected = true
    }
    
    func unsubscribeFromCommunityPosts() async {
        print("Unsubscribing from community posts (realtime disabled)")
        communityPostsSubscription = nil
        isRealtimeConnected = false
    }
    
    var isSubscribedToCommunityPosts: Bool {
        return isRealtimeConnected
    }
    
    func saveCommunityPost(_ post: CommunityPost) async throws {
        let dateFormatter = ISO8601DateFormatter()
        
        let postRecord = CommunityPostRecord(
            id: post.id.uuidString,
            user_id: post.userID,
            book_id: post.bookID.uuidString,
            session_id: post.sessionID.uuidString,
            title: post.title,
            body: post.body,
            created_at: dateFormatter.string(from: post.createdAt)
        )
        
        print("📝 DEBUG: Preparing to save community post \(post.id)")
        print("📝 DEBUG: Post details - Title: \(post.title)")
        print("📝 DEBUG: Post details - User ID: \(post.userID)")
        print("📝 DEBUG: Post details - Book ID: \(post.bookID)")
        print("📝 DEBUG: Post details - Session ID: \(post.sessionID)")
        
        do {
            print("📝 DEBUG: Executing Supabase insert query")
            try await supabase
                .from("community_posts")
                .insert(postRecord)
                .execute()
            print("📝 DEBUG: Community post saved successfully")
            
            // Notify subscribers that community posts data has changed
            communityPostsPublisher.send()
            print("📝 DEBUG: Notified subscribers via publisher")
        } catch {
            print("❌ ERROR: Failed to save community post: \(error.localizedDescription)")
            print("❌ ERROR: Full error details: \(error)")
            print("Error saving community post: \(error.localizedDescription)")
            throw error
        }
    }
    
    func getCommunityPosts() async throws -> [CommunityPost] {
        let result = try await supabase
            .from("community_posts")
            .select("*")
            .order("created_at", ascending: false)
            .execute()
        
        // Parse the response data
        let postsArray = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        
        var communityPosts: [CommunityPost] = []
        
        for postData in postsArray {
            if let id = postData["id"] as? String,
               let userId = postData["user_id"] as? String,
               let bookId = postData["book_id"] as? String,
               let sessionId = postData["session_id"] as? String,
               let title = postData["title"] as? String,
               let body = postData["body"] as? String,
               let createdAtString = postData["created_at"] as? String,
               let createdAt = ISO8601DateFormatter().date(from: createdAtString) {
                
                // Use a placeholder username until we can fix the proper relationship
                let userName = "User " + userId.prefix(4)
                
                let post = CommunityPost(
                    id: UUID(uuidString: id) ?? UUID(),
                    userID: userId,
                    userName: userName,
                    bookID: UUID(uuidString: bookId) ?? UUID(),
                    sessionID: UUID(uuidString: sessionId) ?? UUID(),
                    title: title,
                    body: body,
                    createdAt: createdAt
                )
                
                communityPosts.append(post)
            }
        }
        
        return communityPosts
    }
    
    func getCommunityPost(id: String) async throws -> CommunityPost? {
        let result = try await supabase
            .from("community_posts")
            .select("*")
            .eq("id", value: id)
            .execute()
        
        // Parse the response data
        let postsArray = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        
        guard let postData = postsArray.first,
              let id = postData["id"] as? String,
              let userId = postData["user_id"] as? String,
              let bookId = postData["book_id"] as? String,
              let sessionId = postData["session_id"] as? String,
              let title = postData["title"] as? String,
              let body = postData["body"] as? String,
              let createdAtString = postData["created_at"] as? String,
              let createdAt = ISO8601DateFormatter().date(from: createdAtString) else {
            return nil
        }
        
        // Use a placeholder username until we can fix the proper relationship
        let userName = "User " + userId.prefix(4)
        
        var post = CommunityPost(
            id: UUID(uuidString: id) ?? UUID(),
            userID: userId,
            userName: userName,
            bookID: UUID(uuidString: bookId) ?? UUID(),
            sessionID: UUID(uuidString: sessionId) ?? UUID(),
            title: title,
            body: body,
            createdAt: createdAt
        )
        
        // Get related book and session information
        if let book = try? await getBook(bookId: post.bookID.uuidString) {
            post.book = book
        }
        
        if let session = try? await getReadingSession(sessionId: post.sessionID.uuidString) {
            post.session = session
        }
        
        return post
    }
    
    func deleteCommunityPost(id: String) async throws {
        try await supabase
            .from("community_posts")
            .delete()
            .eq("id", value: id)
            .execute()
        
        // Notify subscribers that community posts data has changed
        communityPostsPublisher.send()
    }
    
    // MARK: - Utility Methods
    
    func clearAllUserData(userId: String) async throws {
        // Clear all user data in case of account deletion or reset
        try await supabase
            .from("reading_sessions")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        try await supabase
            .from("books")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        try await supabase
            .from("profiles")
            .delete()
            .eq("id", value: userId)
            .execute()
        
        // Delete profile photo - ignore errors if the photo doesn't exist
        do {
            _ = try await supabase.storage
                .from("private-user-content")
                .remove(paths: ["profile_photos/\(userId).jpg"])
        } catch {
            print("Error removing profile photo: \(error.localizedDescription)")
        }
        
        // Notify all publishers
        booksPublisher.send()
        sessionsPublisher.send()
        userPublisher.send()
    }
    
    // Method to get a single book by ID
    private func getBook(bookId: String) async throws -> Book? {
        let result = try await supabase
            .from("books")
            .select()
            .eq("id", value: bookId)
            .execute()
        
        // Parse the response data
        let booksArray = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        
        // Return the first book if found
        if let bookData = booksArray.first,
           let id = UUID(uuidString: bookId),
           let isbn = bookData["isbn"] as? String,
           let title = bookData["title"] as? String,
           let author = bookData["author"] as? String {
            
            let coverURL = bookData["cover_url"] as? String
            let currentPage = bookData["current_page"] as? Int ?? 0
            let totalPages = bookData["total_pages"] as? Int
            
            return Book(
                id: id,
                isbn: isbn,
                title: title,
                author: author,
                coverURL: coverURL,
                currentPage: currentPage,
                totalPages: totalPages
            )
        }
        
        return nil
    }
    
    // Method to get a single reading session by ID
    private func getReadingSession(sessionId: String) async throws -> ReadingSession? {
        let result = try await supabase
            .from("reading_sessions")
            .select()
            .eq("id", value: sessionId)
            .execute()
        
        // Parse the response data
        let sessionsArray = parseDataResponse(result.data, defaultValue: [[String: Any]]()) as [[String: Any]]
        
        // Return the first session if found
        if let sessionData = sessionsArray.first,
           let id = UUID(uuidString: sessionId),
           let _ = sessionData["user_id"] as? String,
           let bookIdString = sessionData["book_id"] as? String,
           let bookId = UUID(uuidString: bookIdString),
           let startTimeString = sessionData["start_time"] as? String,
           let startTime = ISO8601DateFormatter().date(from: startTimeString) {
            
            // Optional fields
            let endTimeString = sessionData["end_time"] as? String
            let endTime = endTimeString != nil ? ISO8601DateFormatter().date(from: endTimeString!) : nil
            
            let startPage = sessionData["start_page"] as? Int ?? 0
            let endPage = sessionData["end_page"] as? Int
            let aiSummary = sessionData["ai_summary"] as? String
            let transcript = sessionData["transcript"] as? String
            
            // Check if the ReadingSession initializer accepts userID
            // If it does not, remove that parameter
            return ReadingSession(
                id: id,
                bookID: bookId,
                startTime: startTime,
                endTime: endTime,
                startPage: startPage,
                endPage: endPage,
                aiSummary: aiSummary,
                transcript: transcript
            )
        }
        
        return nil
    }
} 