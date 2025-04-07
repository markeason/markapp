//
//  RecordViewModel.swift
//  markapp
//
//  Created by Eason Tang on 4/2/25.
//

import Foundation
import Combine

class RecordViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var selectedBook: Book?
    @Published var currentSession: ReadingSession?
    @Published var isRunning: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    @Published var showingTranscript: Bool = false
    @Published var isTransitioning: Bool = false
    
    let transcriptionManager = TranscriptionManager()
    
    private var timer: Timer?
    private var startTime: Date?
    private var transcriptionWorkItem: DispatchWorkItem?
    
    init() {
        loadBooks()
    }
    
    func loadBooks() {
        books = DataManager.shared.loadBooks()
    }
    
    func selectBook(_ book: Book) {
        selectedBook = book
    }
    
    func getLastSessionPage(for book: Book) -> Int? {
        let sessions = DataManager.shared.getSessionsForBook(withID: book.id)
        return sessions.sorted(by: { $0.startTime > $1.startTime }).first?.endPage
    }
    
    func startReading(startPage: Int?) {
        guard let book = selectedBook else { return }
        
        // Use provided start page, last session's end page, or the book's current page
        let page = startPage ?? getLastSessionPage(for: book) ?? book.currentPage
        
        let newSession = ReadingSession(
            bookID: book.id,
            startTime: Date(),
            startPage: page
        )
        
        currentSession = newSession
        startTime = Date()
        
        // Start the timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
        
        isRunning = true
        
        // Start voice recognition
        transcriptionManager.startRecording()
    }
    
    func pauseReading() {
        // Update UI state immediately
        isRunning = false
        isTransitioning = true
        
        // Stop timer
        timer?.invalidate()
        
        // Use a background queue for the heavy operations
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Pause voice recognition
            self.transcriptionManager.stopRecording()
            
            DispatchQueue.main.async {
                self.isTransitioning = false
            }
        }
        
        self.transcriptionWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    func resumeReading() {
        guard currentSession != nil else { return }
        
        // Update UI state immediately
        isRunning = true
        isTransitioning = true
        
        // Adjust start time to account for elapsed time so far
        startTime = Date().addingTimeInterval(-elapsedTime)
        
        // Restart timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
        
        // Use a background queue for the heavy operations
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Resume voice recognition
            self.transcriptionManager.startRecording()
            
            DispatchQueue.main.async {
                self.isTransitioning = false
            }
        }
        
        self.transcriptionWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
    }
    
    func finishReading(endPage: Int) {
        guard var session = currentSession, let book = selectedBook else { return }
        
        // Cancel any ongoing operations
        transcriptionWorkItem?.cancel()
        
        // Stop timer
        timer?.invalidate()
        isRunning = false
        
        // Stop voice recognition
        transcriptionManager.stopRecording()
        
        // Update session details
        session.endTime = Date()
        session.endPage = endPage
        session.transcript = transcriptionManager.transcript
        
        // Save session
        DataManager.shared.addSession(session)
        
        // Update book's current page
        var updatedBook = book
        updatedBook.currentPage = endPage
        DataManager.shared.updateBook(updatedBook)
        
        // Reset current state
        currentSession = nil
        elapsedTime = 0
        selectedBook = nil
        transcriptionManager.reset()
        showingTranscript = false
        isTransitioning = false
    }
    
    func cancelReading() {
        // Cancel any ongoing operations
        transcriptionWorkItem?.cancel()
        
        timer?.invalidate()
        isRunning = false
        currentSession = nil
        elapsedTime = 0
        selectedBook = nil
        
        // Stop voice recognition
        transcriptionManager.reset()
        showingTranscript = false
        isTransitioning = false
    }
    
    func toggleTranscript() {
        // Update the visibility state
        showingTranscript.toggle()
        print("Transcript visibility toggled to: \(showingTranscript)")
        
        // If turning on transcript for the first time and not already recording, start recording
        if showingTranscript {
            if !transcriptionManager.isRecording && isRunning {
                print("Starting recording because transcript was toggled on")
                
                // Stop any existing recording first
                transcriptionManager.stopRecording()
                
                // Wait a moment then start a new recording session
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.transcriptionManager.startRecording()
                }
            }
            
            // If we don't have a transcript yet, force restart recognition
            if transcriptionManager.transcript.isEmpty && isRunning {
                print("Restarting recording because transcript is empty")
                transcriptionManager.stopRecording()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.transcriptionManager.startRecording()
                }
            }
        }
    }
    
    var formattedElapsedTime: String {
        let totalSeconds = Int(elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}
