//
//  SessionDetailViewModel.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import Foundation
import Combine

class SessionDetailViewModel: ObservableObject {
    @Published var session: ReadingSession
    @Published var book: Book?
    @Published var isLoadingSummary = false
    @Published var summaryError: String? = nil

    init(session: ReadingSession) {
        self.session = session
        loadBookDetails()
    }

    private func loadBookDetails() {
        let books = DataManager.shared.loadBooks()
        self.book = books.first { $0.id == session.bookID }
    }

    // MARK: - Summary Generation

    func generateSummary() async {
        guard let book = book, let endPage = session.endPage else { return }

        await MainActor.run {
            isLoadingSummary = true
            summaryError = nil
        }

        do {
            let summary = try await AIService.shared.generateReadingSummary(
                book: book,
                startPage: session.startPage,
                endPage: endPage
            )

            // Update session in database
            var updatedSession = session
            updatedSession.aiSummary = summary
            
            DataManager.shared.updateSession(updatedSession)

            await MainActor.run {
                self.session = updatedSession
                isLoadingSummary = false
            }
        } catch {
            await MainActor.run {
                summaryError = "Could not generate summary: \(error.localizedDescription)"
                isLoadingSummary = false
            }
        }
    }

    var displaySummary: String {
        if isLoadingSummary {
            return "Generating summary..."
        }

        if let error = summaryError {
            return "Error: \(error)"
        }

        return session.aiSummary ?? placeholderSummary
    }

    // MARK: - Advanced Statistics

    var pagesRead: Int {
        guard let endPage = session.endPage else { return 0 }
        return endPage - session.startPage
    }

    var readingTimeMinutes: Double {
        session.duration / 60
    }

    var minutesPerPage: Double {
        guard pagesRead > 0 else { return 0 }
        return readingTimeMinutes / Double(pagesRead)
    }

    var estimatedWordsRead: Int {
        pagesRead * 250
    }

    var readingSpeed: Int {
        guard let pagesRead = session.pagesRead, session.readingTimeMinutes > 0 else { return 0 }
        return Int(Double(pagesRead) / session.readingTimeMinutes)
    }

    // MARK: - Formatted Outputs

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: session.startTime)
    }

    var formattedDuration: String {
        let totalSeconds = Int(session.duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedMinutesPerPage: String {
        String(format: "%.1f", minutesPerPage)
    }

    // MARK: - Dummy Book Summary

    var placeholderSummary: String {
        """
        Click generate to view your personalized summary
        """
    }
    
    // MARK: - Session Management
    
    func deleteSession() {
        DataManager.shared.deleteSession(withID: session.id)
    }
}
