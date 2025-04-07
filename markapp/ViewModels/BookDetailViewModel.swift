//
//  BookDetailViewModel.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//
import Foundation
import Combine

class BookDetailViewModel: ObservableObject {
    @Published var book: Book
    @Published var sessions: [ReadingSession] = []
    @Published var isRefreshing = false
    
    private var cachedTotalPagesRead: Int?
    private var cachedTotalReadingTime: TimeInterval?
    
    init(book: Book) {
        self.book = book
        loadSessions()
    }
    
    func loadSessions() {
        // Reset cached values
        cachedTotalPagesRead = nil
        cachedTotalReadingTime = nil
        
        // Load sessions
        sessions = DataManager.shared.getSessionsForBook(withID: book.id)
        sessions.sort { $0.startTime > $1.startTime } // Most recent first
    }
    
    func refreshData() async {
        await MainActor.run {
            isRefreshing = true
        }
        
        // Refresh data from Supabase
        await DataManager.shared.refreshData()
        
        // Update the book with the latest data from local storage
        let allBooks = DataManager.shared.loadBooks()
        if let updatedBook = allBooks.first(where: { $0.id == book.id }) {
            await MainActor.run {
                self.book = updatedBook
            }
        }
        
        await MainActor.run {
            loadSessions()
            isRefreshing = false
        }
    }
    
    var totalPagesRead: Int {
        if let cached = cachedTotalPagesRead {
            return cached
        }
        
        let total = sessions.compactMap { $0.pagesRead }.reduce(0, +)
        cachedTotalPagesRead = total
        return total
    }
    
    var totalReadingTime: TimeInterval {
        if let cached = cachedTotalReadingTime {
            return cached
        }
        
        let total = sessions.map { $0.duration }.reduce(0, +)
        cachedTotalReadingTime = total
        return total
    }
    
    func formattedTotalTime() -> String {
        let totalSeconds = Int(totalReadingTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    func deleteBook() {
        DataManager.shared.deleteBook(withID: book.id)
    }
}
