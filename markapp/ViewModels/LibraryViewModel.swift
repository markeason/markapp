//
//  LibraryViewModel.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import Foundation
import SwiftUI
import Combine

class LibraryViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingTotalPagesPrompt = false
    @Published var pendingBook: Book?
    @Published var shouldDismissParentView = false
    @Published var isRefreshing = false
    
    init() {
        loadBooks()
    }
    
    func loadBooks() {
        books = DataManager.shared.loadBooks()
    }
    
    func refreshBooks() async {
        await MainActor.run {
            isRefreshing = true
        }
        
        // Fetch updated data from Supabase
        await DataManager.shared.refreshData()
        
        await MainActor.run {
            loadBooks()
            isRefreshing = false
        }
    }
    
    func addBookByISBN(_ isbn: String) async {
        let trimmedISBN = isbn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedISBN.isEmpty else {
            await MainActor.run {
                self.errorMessage = "Please enter a valid ISBN"
            }
            return
        }
        
        if books.contains(where: { $0.isbn == trimmedISBN }) {
            await MainActor.run {
                self.errorMessage = "This book is already in your library"
            }
            return
        }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let book = try await BookService.shared.fetchBookDetails(isbn: trimmedISBN)
            
            await MainActor.run {
                // Check if the book has page count data
                if book.totalPages == nil || book.totalPages == 0 {
                    // No page count data, we need to prompt user
                    self.pendingBook = book
                    self.showingTotalPagesPrompt = true
                    self.isLoading = false
                } else {
                    // Book has page count, add it directly
                    self.saveBook(book)
                }
            }
        } catch let error as URLError {
            await MainActor.run {
                self.errorMessage = "Network error: \(error.localizedDescription)"
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription.contains("Book not found")
                    ? "Book not found. Please check the ISBN."
                    : "Something went wrong: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    func saveBook(_ book: Book) {
        DataManager.shared.addBook(book)
        books.append(book)
        isLoading = false
        pendingBook = nil
        showingTotalPagesPrompt = false
        shouldDismissParentView = true
        
        // Book is saved, parent view should now dismiss
    }
    
    func savePendingBookWithPages(_ updatedBook: Book) {
        saveBook(updatedBook)
    }
    
    func cancelPendingBook() {
        pendingBook = nil
        showingTotalPagesPrompt = false
        isLoading = false
        shouldDismissParentView = true
    }
    
    func deleteBook(at indexSet: IndexSet) {
        let booksToDelete = indexSet.map { books[$0] }
        for book in booksToDelete {
            DataManager.shared.deleteBook(withID: book.id)
        }
        loadBooks() // Refresh the books list
    }

    func deleteBook(withID id: UUID) {
        DataManager.shared.deleteBook(withID: id)
        loadBooks() // Refresh the books list
    }
}
