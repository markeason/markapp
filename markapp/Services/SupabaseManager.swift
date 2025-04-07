import AppConfig
import Foundation
import Supabase
import Combine

// Profile entity for Supabase
struct ProfileRecord: Encodable {
    let id: String
    let name: String
    let location: String
    let join_date: String
    let profile_photo_url: String?
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
    
    private init() {
        self.supabase = SupabaseClient(
            supabaseURL: URL(string: AppConfig.supabaseURL)!,
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
            let session = try await supabase.auth.session
            
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
} 