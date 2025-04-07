import SwiftUI

struct RecordView: View {
    @StateObject private var viewModel = RecordViewModel()
    @State private var showingBookSelection = false
    @State private var showingPagePrompt = false
    @State private var showingEndPrompt = false
    @State private var startPage: String = ""
    @State private var endPage: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if viewModel.currentSession == nil {
                    // Book selection state
                    VStack(spacing: 40) {
                        if !viewModel.books.isEmpty {
                            // Start reading view
                            VStack(spacing: 30) {
                                Text("Start Reading")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.secondary)
                                
                                Button {
                                    showingBookSelection = true
                                } label: {
                                    Text("Select Book")
                                        .font(.system(size: 18, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal, 40)
                            }
                        } else {
                            // Empty library state
                            VStack(spacing: 30) {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary)
                                
                                Text("No Books in Library")
                                    .font(.system(size: 24, weight: .light))
                                    .foregroundColor(.secondary)
                                
                                NavigationLink(destination: LibraryView()) {
                                    Text("Add Books")
                                        .font(.system(size: 18, weight: .medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                                .padding(.horizontal, 40)
                            }
                        }
                    }
                } else {
                    // Active session view
                    VStack(spacing: 0) {
                        Spacer()
                        
                        // Book info
                        if let book = viewModel.selectedBook {
                            VStack(spacing: 16) {
                                ImprovedCoverImageView(
                                    coverURLString: book.coverURL,
                                    width: 100,
                                    height: 150
                                )
                                .shadow(radius: 3)
                                
                                VStack(spacing: 8) {
                                    Text(book.title)
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    
                                    Text("Page \(viewModel.currentSession?.startPage ?? 0)")
                                        .font(.system(size: 16, weight: .light))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.bottom, 30)
                        }
                        
                        // Timer
                        Text(viewModel.formattedElapsedTime)
                            .font(.system(size: 72, weight: .light))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                            .padding(.bottom, 20)
                        
                        // Audio waveform (only visible when recording)
                        if viewModel.transcriptionManager.isRecording {
                            AudioWaveformView(levels: viewModel.transcriptionManager.audioLevels, color: .blue)
                                .frame(height: 50)
                                .padding(.horizontal)
                        }
                        
                        // Recording indicator
                        if viewModel.transcriptionManager.isRecording {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 10, height: 10)
                                Text("Recording voice")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 5)
                            .padding(.bottom, 20)
                        } else if !viewModel.transcriptionManager.permissionGranted {
                            Text("Microphone access required for voice recording")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.vertical, 10)
                        } else if let errorMessage = viewModel.transcriptionManager.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.vertical, 10)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Transcript display area (toggled by button)
                        if viewModel.showingTranscript {
                            ScrollView {
                                VStack(alignment: .leading) {
                                    Text("Live Transcript")
                                        .font(.headline)
                                        .padding(.bottom, 5)
                                    
                                    if viewModel.transcriptionManager.transcript.isEmpty {
                                        Text("No transcript available yet. Continue reading aloud...")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .italic()
                                    } else {
                                        Text(viewModel.transcriptionManager.transcript)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .frame(maxHeight: 150)
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                        
                        // Controls
                        HStack(spacing: 20) {
                            Button {
                                if viewModel.isRunning {
                                    viewModel.pauseReading()
                                } else {
                                    viewModel.resumeReading()
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    if viewModel.isTransitioning {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                                            .font(.system(size: 24))
                                    }
                                    Text(viewModel.isRunning ? "Pause" : "Resume")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .frame(width: 80)
                            }
                            .disabled(viewModel.isTransitioning)
                            
                            Button {
                                showingEndPrompt = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 24))
                                    Text("Finish")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.green)
                                .frame(width: 80)
                            }
                            
                            Button {
                                viewModel.cancelReading()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 24))
                                    Text("Cancel")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.red)
                                .frame(width: 80)
                            }
                            
                            Button {
                                viewModel.toggleTranscript()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: viewModel.showingTranscript ? "text.bubble.fill" : "text.bubble")
                                        .font(.system(size: 24))
                                    Text("Transcript")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.blue)
                                .frame(width: 80)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.showingTranscript ? Color.blue.opacity(0.1) : Color.clear)
                            )
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Record Reading")
            .sheet(isPresented: $showingBookSelection) {
                BookSelectionView(books: viewModel.books) { selectedBook in
                    viewModel.selectedBook = selectedBook
                    
                    // Always show the page prompt so the user can confirm or adjust the starting page
                    // We'll pre-populate with the last session's end page or book's current page
                    showingPagePrompt = true
                }
            }
            .sheet(isPresented: $showingPagePrompt) {
                PagePromptView(
                    title: "Starting Page",
                    message: "What page are you starting on?",
                    initialPage: viewModel.selectedBook.flatMap { viewModel.getLastSessionPage(for: $0) } ?? viewModel.selectedBook?.currentPage ?? 1,
                    maxPages: viewModel.selectedBook?.totalPages ?? 1000
                ) { page in
                    viewModel.startReading(startPage: page)
                }
            }
            .sheet(isPresented: $showingEndPrompt) {
                PagePromptView(
                    title: "Finishing Page",
                    message: "What page did you finish on?",
                    initialPage: viewModel.currentSession?.startPage ?? 1,
                    maxPages: viewModel.selectedBook?.totalPages ?? 1000
                ) { page in
                    viewModel.finishReading(endPage: page)
                }
            }
            .onAppear {
                viewModel.loadBooks()
            }
        }
    }
}
