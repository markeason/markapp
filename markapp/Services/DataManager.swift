//
//  DataManager.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import Foundation
import SwiftUI
import Combine

class DataManager {
    static let shared = DataManager()
    
    private let booksKey = "savedBooks"
    private let sessionsKey = "readingSessions"
    private let userKey = "userData"
    
    // Add flags for syncing to avoid duplicate operations
    private var isSyncingBooks = false
    private var isSyncingSessions = false
    private var isSyncingUser = false
    
    // Add cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // Reference to AuthManager
    private var authManager: AuthManager?
    
    private init() {
        // Subscribe to Supabase data changes to update local storage
        setupSubscriptions()
    }
    
    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }
    
    private func setupSubscriptions() {
        // Listen for book changes from Supabase
        SupabaseManager.shared.booksPublisher
            .sink { [weak self] _ in
                Task {
                    await self?.syncBooksFromSupabase()
                }
            }
            .store(in: &cancellables)
        
        // Listen for session changes from Supabase
        SupabaseManager.shared.sessionsPublisher
            .sink { [weak self] _ in
                Task {
                    await self?.syncSessionsFromSupabase()
                }
            }
            .store(in: &cancellables)
        
        // Listen for user changes from Supabase
        SupabaseManager.shared.userPublisher
            .sink { [weak self] _ in
                Task {
                    await self?.syncUserFromSupabase()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - User Data
    
    func saveUser(_ user: User) {
        // Save locally
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userKey)
        }
        
        // Sync to Supabase if user is logged in
        Task {
            await syncUserToSupabase(user)
        }
    }
    
    private func syncUserToSupabase(_ user: User) async {
        guard !isSyncingUser, let userId = await getCurrentUserId() else {
            print("Skipping user sync: User not logged in or sync already in progress")
            return
        }
        
        isSyncingUser = true
        
        do {
            // Check network connection before sync attempt
            if let authManager = authManager, !authManager.isConnected {
                print("Skipping user sync: Network connection unavailable")
                isSyncingUser = false
                return
            }
            
            print("Starting profile sync to Supabase for user: \(userId)")
            try await SupabaseManager.shared.saveUserProfile(user, userId: userId)
            print("Profile sync complete")
        } catch {
            print("Error syncing user to Supabase: \(error.localizedDescription)")
            // If there's a network error, we'll retry later when network is available
            if let urlError = error as? URLError, 
               urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
                print("Network error detected, will retry on next connection")
            }
        }
        
        isSyncingUser = false
    }
    
    private func syncUserFromSupabase() async {
        guard !isSyncingUser, let userId = await getCurrentUserId() else {
            return
        }
        
        isSyncingUser = true
        
        do {
            if let user = try await SupabaseManager.shared.getUserProfile(userId: userId) {
                if let encoded = try? JSONEncoder().encode(user) {
                    UserDefaults.standard.set(encoded, forKey: userKey)
                }
            }
        } catch {
            print("Error syncing user from Supabase: \(error.localizedDescription)")
        }
        
        isSyncingUser = false
    }
    
    func loadUser() -> User {
        guard let data = UserDefaults.standard.data(forKey: userKey),
              let user = try? JSONDecoder().decode(User.self, from: data) else {
            return User.empty
        }
        return user
    }
    
    func getRecentlyReadBooks() -> [Book] {
        let sessions = loadSessions()
            .sorted { $0.endTime ?? Date() > $1.endTime ?? Date() }
        
        var books: [Book] = []
        var seenBookIDs: Set<UUID> = []
        
        // Get all books
        let allBooks = loadBooks()
        
        // Find the 3 most recently read books
        for session in sessions {
            guard seenBookIDs.count < 3,
                  let book = allBooks.first(where: { $0.id == session.bookID }),
                  !seenBookIDs.contains(book.id) else {
                continue
            }
            
            books.append(book)
            seenBookIDs.insert(book.id)
        }
        
        return books
    }
    
    // MARK: - Books
    
    func saveBooks(_ books: [Book]) {
        // Save locally
        if let encoded = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(encoded, forKey: booksKey)
        }
        
        // Sync all books to Supabase
        Task {
            await syncBooksToSupabase(books)
        }
    }
    
    private func syncBooksToSupabase(_ books: [Book]) async {
        guard !isSyncingBooks, let userId = await getCurrentUserId() else {
            return
        }
        
        isSyncingBooks = true
        
        do {
            // Sync each book individually
            for book in books {
                try await SupabaseManager.shared.saveBook(book, userId: userId)
            }
        } catch {
            print("Error syncing books to Supabase: \(error.localizedDescription)")
        }
        
        isSyncingBooks = false
    }
    
    private func syncBooksFromSupabase() async {
        guard !isSyncingBooks, let userId = await getCurrentUserId() else {
            return
        }
        
        isSyncingBooks = true
        
        do {
            let books = try await SupabaseManager.shared.getBooks(userId: userId)
            if let encoded = try? JSONEncoder().encode(books) {
                UserDefaults.standard.set(encoded, forKey: booksKey)
            }
        } catch {
            print("Error syncing books from Supabase: \(error.localizedDescription)")
        }
        
        isSyncingBooks = false
    }
    
    func loadBooks() -> [Book] {
        guard let data = UserDefaults.standard.data(forKey: booksKey),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return []
        }
        return books
    }
    
    func addBook(_ book: Book) {
        var books = loadBooks()
        
        // Check if this book with the same ISBN already exists
        if let existingIndex = books.firstIndex(where: { $0.isbn == book.isbn }) {
            print("Book with ISBN \(book.isbn) already exists. Updating it instead of adding.")
            
            // Keep the existing ID but update other fields
            let existingBook = books[existingIndex]
            let updatedBook = Book(
                id: existingBook.id,  // Keep the existing ID
                isbn: book.isbn,
                title: book.title,
                author: book.author,
                coverURL: book.coverURL,
                currentPage: book.currentPage,
                totalPages: book.totalPages
            )
            
            books[existingIndex] = updatedBook
        } else {
            // Only add the book if it doesn't exist
            books.append(book)
        }
        
        saveBooks(books)
    }
    
    func updateBook(_ book: Book) {
        var books = loadBooks()
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
            saveBooks(books)
        }
    }
    
    // MARK: - Reading Sessions
    
    func saveSessions(_ sessions: [ReadingSession]) {
        // Save locally
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsKey)
        }
        
        // Sync to Supabase
        Task {
            await syncSessionsToSupabase(sessions)
        }
    }
    
    private func syncSessionsToSupabase(_ sessions: [ReadingSession]) async {
        guard !isSyncingSessions, let userId = await getCurrentUserId() else {
            return
        }
        
        isSyncingSessions = true
        
        do {
            // Sync each session individually
            for session in sessions {
                try await SupabaseManager.shared.saveSession(session, userId: userId)
            }
        } catch {
            print("Error syncing sessions to Supabase: \(error.localizedDescription)")
        }
        
        isSyncingSessions = false
    }
    
    private func syncSessionsFromSupabase() async {
        guard !isSyncingSessions, let userId = await getCurrentUserId() else {
            return
        }
        
        isSyncingSessions = true
        
        do {
            let sessions = try await SupabaseManager.shared.getSessions(userId: userId)
            if let encoded = try? JSONEncoder().encode(sessions) {
                UserDefaults.standard.set(encoded, forKey: sessionsKey)
            }
        } catch {
            print("Error syncing sessions from Supabase: \(error.localizedDescription)")
        }
        
        isSyncingSessions = false
    }
    
    func loadSessions() -> [ReadingSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([ReadingSession].self, from: data) else {
            return []
        }
        return sessions
    }
    
    func addSession(_ session: ReadingSession) {
        var sessions = loadSessions()
        sessions.append(session)
        saveSessions(sessions)
    }
    
    func updateSession(_ session: ReadingSession) {
        var sessions = loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
            saveSessions(sessions)
        }
    }
    
    func getSessionsForBook(withID id: UUID) -> [ReadingSession] {
        return loadSessions().filter { $0.bookID == id }
    }
    
    func deleteSession(withID id: UUID) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == id }
        saveSessions(sessions)
        
        // Delete from Supabase
        Task {
            if let userId = await getCurrentUserId() {
                try? await SupabaseManager.shared.deleteSession(sessionId: id, userId: userId)
            }
        }
    }
    
    func deleteBook(withID id: UUID) {
        // Delete the book locally
        var books = loadBooks()
        books.removeAll { $0.id == id }
        saveBooks(books)
        
        // Clean up associated reading sessions locally
        var sessions = loadSessions()
        sessions.removeAll { $0.bookID == id }
        saveSessions(sessions)
        
        // Delete from Supabase
        Task {
            if let userId = await getCurrentUserId() {
                try? await SupabaseManager.shared.deleteBook(bookId: id, userId: userId)
            }
        }
    }
    
    // MARK: - Utilities
    
    private func getCurrentUserId() async -> String? {
        // Return the user ID from the AuthManager if available
        if let session = authManager?.session {
            return session.user.id.uuidString
        }
        return nil
    }
    
    // MARK: - Initial Sync
    
    func performInitialSync() async {
        if await getCurrentUserId() == nil { return }
        
        // First sync data from Supabase to local storage
        await syncUserFromSupabase()
        await syncBooksFromSupabase()
        await syncSessionsFromSupabase()
        
        // Then sync local data to Supabase in case there's data that wasn't saved yet
        await syncUserToSupabase(loadUser())
        await syncBooksToSupabase(loadBooks())
        await syncSessionsToSupabase(loadSessions())
    }
    
    // MARK: - Refresh Data
    
    /// Fetches the latest data from Supabase
    func refreshData() async {
        print("Refreshing data from Supabase...")
        
        // Only fetch if the user is logged in
        guard await getCurrentUserId() != nil else { 
            print("No user logged in - skipping refresh")
            return 
        }
        
        // Check network connection before sync attempt
        if let authManager = authManager, !authManager.isConnected {
            print("Skipping refresh: Network connection unavailable")
            return
        }
        
        // Fetch all data types from Supabase
        await syncUserFromSupabase()
        await syncBooksFromSupabase()
        await syncSessionsFromSupabase()
        
        print("Data refresh completed")
    }
}
